using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Linq;
using System.Net.NetworkInformation;

class Program
{
    static void Main(string[] args)
    {
        const int port = 8765;
        Console.WriteLine($"[TouchBoard Agent] Servidor escutando na porta {port}...");
        UdpClient udp = new UdpClient(port);
        IPEndPoint ep = new IPEndPoint(IPAddress.Any, port);

        while (true)
        {
            try
            {
                byte[] data = udp.Receive(ref ep);
                string msg = Encoding.UTF8.GetString(data);

                using var doc = JsonDocument.Parse(msg);
                if (!doc.RootElement.TryGetProperty("Type", out var typeProp))
                    continue;

                string type = typeProp.GetString() ?? string.Empty;

                switch (type)
                {
                    case "key":
                    {
                        string key = doc.RootElement.GetProperty("Key").GetString() ?? "Z";
                        bool pressed = doc.RootElement.GetProperty("Pressed").GetBoolean();
                        Console.WriteLine($"[KEY] {key} {(pressed ? "DOWN" : "UP")}");
                        WinInput.SendKey(WinInput.VkFromLetter(key[0]), pressed);
                        break;
                    }

                    case "mouseMove":
                    {
                        double x = doc.RootElement.GetProperty("X").GetDouble();
                        double y = doc.RootElement.GetProperty("Y").GetDouble();
                        Console.WriteLine($"[MOUSE MOVE] X={x:F1} Y={y:F1}");
                        WinInput.MoveAbsolute(x, y);
                        break;
                    }

                    case "mouseDown":
                        Console.WriteLine("[MOUSE DOWN]");
                        WinInput.MouseDown();
                        break;

                    case "mouseUp":
                        Console.WriteLine("[MOUSE UP]");
                        WinInput.MouseUp();
                        break;

                    // ======= NOVO: responder descoberta automática =======
                    case "discover":
                    {
                        string host = GetPreferredLocalIPv4() ?? "127.0.0.1";
                        var reply = JsonSerializer.Serialize(new { Type = "hello", Host = host, Port = port });
                        byte[] replyData = Encoding.UTF8.GetBytes(reply);
                        udp.Send(replyData, replyData.Length, ep); // responde para quem perguntou
                        Console.WriteLine($"[DISCOVER] Reply -> {host}:{port} para {ep.Address}");
                        break;
                    }

                    // ======= Já tínhamos: retorna resolução da tela =======
                    case "getScreen":
                    {
                        int w = WinInput.GetScreenWidth();
                        int h = WinInput.GetScreenHeight();
                        var reply = JsonSerializer.Serialize(new { Type = "screenInfo", Width = w, Height = h });
                        byte[] replyData = Encoding.UTF8.GetBytes(reply);
                        udp.Send(replyData, replyData.Length, ep);
                        Console.WriteLine($"[SCREEN] {w}x{h} enviado para {ep.Address}");
                        break;
                    }

                    default:
                        // silencioso
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Erro: {ex.Message}");
            }
        }
    }

    // pega um IPv4 local “usável” (ignora loopback e redes virtuais)
    static string? GetPreferredLocalIPv4()
    {
        foreach (var ni in NetworkInterface.GetAllNetworkInterfaces()
                 .Where(n => n.OperationalStatus == OperationalStatus.Up))
        {
            var ipProps = ni.GetIPProperties();
            foreach (var ua in ipProps.UnicastAddresses)
            {
                if (ua.Address.AddressFamily == AddressFamily.InterNetwork &&
                    !IPAddress.IsLoopback(ua.Address))
                    return ua.Address.ToString();
            }
        }
        return null;
    }
}
