import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:math' as math;

// ============================
// BOOT: paisagem + imersivo
// ============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const TouchBoardApp());
}

// ============================
// App root + Provider
// ============================
class TouchBoardApp extends StatelessWidget {
  const TouchBoardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => Transport())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TouchBoard MVP',
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Sans'),
        home: const HomePage(),
      ),
    );
  }
}

// ============================
// Camada de transporte UDP
// ============================
class Transport extends ChangeNotifier {
  InternetAddress host =
      InternetAddress.tryParse('172.31.61.122') ?? InternetAddress.loopbackIPv4;
  int port = 8765;
  int _seq = 0;

  void configure(String ip, int p) {
    host = InternetAddress(ip);
    port = p;
    notifyListeners();
  }

  Future<void> send(Map<String, dynamic> msg) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    msg['v'] = 1;
    msg['seq'] = _seq++;
    final data = utf8.encode(jsonEncode(msg));
    socket.send(data, host, port);
    // debug
    // ignore: avoid_print
    print('📤 Enviado: $msg para $host:$port');
    socket.close();
  }

  /// Descoberta automática do agente (UDP broadcast)
  Future<bool> discoverAgent({int timeoutMs = 1200}) async {
    try {
      final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.broadcastEnabled = true;

      final completer = Completer<bool>();

      sock.listen((event) {
        if (event == RawSocketEvent.read) {
          final d = sock.receive();
          if (d == null) return;
          final msg = utf8.decode(d.data);
          try {
            final json = jsonDecode(msg);
            if (json['Type'] == 'hello') {
              final ip = (json['Host'] as String).trim();
              final p = (json['Port'] as num).toInt();
              configure(ip, p);
              if (!completer.isCompleted) completer.complete(true);
            }
          } catch (_) {}
        }
      });

      // envia broadcast
      final packet = utf8.encode(jsonEncode({"Type": "discover"}));
      sock.send(packet, InternetAddress('255.255.255.255'), port);

      // timeout
      Future.delayed(Duration(milliseconds: timeoutMs)).then((_) {
        if (!completer.isCompleted) completer.complete(false);
      });

      final ok = await completer.future;
      sock.close();
      return ok;
    } catch (_) {
      return false;
    }
  }
}

// ============================
// HOME (stateful p/ autoconnect)
// ============================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // tenta auto-descobrir o agente ao abrir
    Future.microtask(() async {
      final ok = await context.read<Transport>().discoverAgent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Agente encontrado ✅' : 'Não encontrei o agente')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    WakelockPlus.enable();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, cons) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final minH = math.max(0.0, cons.maxHeight - 48);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2B2A4A), Color(0xFF1F1E36)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minH),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PillButton(
                      label: 'Keyboard Mode',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const KeyboardSetupPage()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PillButton(
                      label: 'Tablet/Mouse Mode',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TabletPage()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _ConnectionCard(),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF46464A),
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 6), color: Colors.black54)],
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({super.key});
  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  final ipCtrl = TextEditingController(text: '172.31.61.122');
  final portCtrl = TextEditingController(text: '8765');

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 720;
    return Card(
      color: const Color(0xFF3A3A3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Conexão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _hostField(ipCtrl),
                  const SizedBox(height: 8),
                  _portField(portCtrl, fullWidth: true),
                  const SizedBox(height: 12),
                  _saveBtn(context),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _hostField(ipCtrl)),
                  const SizedBox(width: 12),
                  _portField(portCtrl),
                  const SizedBox(width: 12),
                  _saveBtn(context),
                ],
              ),
      ),
    );
  }

  Widget _hostField(TextEditingController c) => TextField(
        controller: c,
        decoration: const InputDecoration(
          labelText: 'Host (IP do PC)',
          isDense: true,
          border: UnderlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      );

  Widget _portField(TextEditingController c, {bool fullWidth = false}) => SizedBox(
        width: fullWidth ? double.infinity : 100,
        child: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Porta',
            isDense: true,
            border: UnderlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );

  Widget _saveBtn(BuildContext context) => SizedBox(
        width: 110,
        child: ElevatedButton(
          onPressed: () {
            final ip = ipCtrl.text.trim();
            final p = int.tryParse(portCtrl.text.trim()) ?? 8765;
            context.read<Transport>().configure(ip, p);
            FocusScope.of(context).unfocus();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Conexão salva ✅')));
          },
          child: const Text('Salvar'),
        ),
      );
}

// ============================
// KEYBOARD MODE
// ============================
class KeyboardSetupPage extends StatelessWidget {
  const KeyboardSetupPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyboard Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _PillButton(
            label: 'Std/Catch (Z + X)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KeyboardOverlay(keysLayout: ['Z', 'X'])),
            ),
          ),
          const SizedBox(height: 16),
          _PillButton(
            label: 'Mania 4K (Z X C V)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KeyboardOverlay(keysLayout: ['Z', 'X', 'C', 'V'])),
            ),
          ),
        ]),
      ),
    );
  }
}

class KeyboardOverlay extends StatefulWidget {
  final List<String> keysLayout;
  const KeyboardOverlay({super.key, required this.keysLayout});
  @override
  State<KeyboardOverlay> createState() => _KeyboardOverlayState();
}

class _KeyboardOverlayState extends State<KeyboardOverlay> {
  final pressed = <int, bool>{};
  @override
  Widget build(BuildContext context) {
    final transport = context.watch<Transport>();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, c) {
          final buttons = <Widget>[];
          for (var i = 0; i < widget.keysLayout.length; i++) {
            final code = widget.keysLayout[i];
            buttons.add(Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: c.maxWidth * 0.02, vertical: c.maxHeight * 0.06),
                child: Listener(
                  onPointerDown: (_) {
                    setState(() => pressed[i] = true);
                    transport.send({"Type": "key", "Key": code, "Pressed": true});
                  },
                  onPointerUp: (_) {
                    setState(() => pressed[i] = false);
                    transport.send({"Type": "key", "Key": code, "Pressed": false});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    decoration: BoxDecoration(
                      color: pressed[i] == true ? const Color(0xFF2B2B2E) : const Color(0xFF111112),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(blurRadius: 10, color: Colors.black54, offset: Offset(0, 6))
                      ],
                      border: Border.all(color: const Color(0xFF444444), width: 2),
                    ),
                    child: Center(
                      child: Text(code,
                          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ));
          }
          return Row(children: buttons);
        }),
      ),
    );
  }
}

// ============================
// TABLET / MOUSE MODE
// ============================
class TabletPage extends StatefulWidget {
  const TabletPage({super.key});
  @override
  State<TabletPage> createState() => _TabletPageState();
}

class _TabletPageState extends State<TabletPage> {
  bool down = false;
  double? screenW;
  double? screenH;
  RawDatagramSocket? _socket;

  @override
  void initState() {
    super.initState();
    _requestScreenSize();
  }

  Future<void> _requestScreenSize() async {
    final transport = context.read<Transport>();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram == null) return;
        final msg = utf8.decode(datagram.data);
        try {
          final json = jsonDecode(msg);
          if (json["Type"] == "screenInfo") {
            setState(() {
              screenW = (json["Width"] as num).toDouble();
              screenH = (json["Height"] as num).toDouble();
            });
            // ignore: avoid_print
            print("🖥️ Resolução detectada: ${screenW}x${screenH}");
          }
        } catch (_) {}
      }
    });

    final data = utf8.encode(jsonEncode({"Type": "getScreen"}));
    _socket!.send(data, transport.host, transport.port);
    // ignore: avoid_print
    print("📤 Solicitando resolução da tela...");
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transport = context.watch<Transport>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tablet/Mouse')),
      body: LayoutBuilder(builder: (ctx, c) {
        final padW = c.maxWidth * 0.92;
        final padH = c.maxHeight * 0.86;

        return Center(
          child: GestureDetector(
            onPanStart: (details) {
              down = true;
              _send(details.localPosition, padW, padH, down, transport);
            },
            onPanUpdate: (details) {
              if (down) _send(details.localPosition, padW, padH, down, transport);
            },
            onPanEnd: (_) {
              down = false;
              transport.send({"Type": "mouseUp"});
            },
            onTapDown: (details) {
              down = true;
              _send(details.localPosition, padW, padH, down, transport);
            },
            onTapUp: (details) {
              down = false;
              _send(details.localPosition, padW, padH, down, transport);
            },
            child: Container(
              width: padW,
              height: padH,
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3A3A3F), width: 2),
              ),
              child: Center(
                child: screenW == null
                    ? const Text("Carregando resolução...",
                        style: TextStyle(color: Colors.white54))
                    : Text("🖥️ Área ativa (${screenW!.toInt()}x${screenH!.toInt()})",
                        style: const TextStyle(color: Colors.white54, fontSize: 16)),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _send(Offset p, double w, double h, bool isDown, Transport t) {
    if (screenW == null || screenH == null) return;

    final normX = (p.dx.clamp(0, w) / w) * screenW!;
    final normY = (p.dy.clamp(0, h) / h) * screenH!;

    // ignore: avoid_print
    print('📤 Enviando: X=$normX, Y=$normY, Down=$isDown');

    t.send({"Type": "mouseMove", "X": normX, "Y": normY});

    if (isDown) {
      t.send({"Type": "mouseDown"});
    } else {
      t.send({"Type": "mouseUp"});
    }
  }
}
