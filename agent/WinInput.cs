using System;
using System.Runtime.InteropServices;

public static class WinInput
{
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT
    {
        public uint type;
        public InputUnion u;
        public static int Size => Marshal.SizeOf(typeof(INPUT));
    }

    [StructLayout(LayoutKind.Explicit)]
    struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    private const uint INPUT_MOUSE = 0;
    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const uint MOUSEEVENTF_MOVE = 0x0001;
    private const uint MOUSEEVENTF_ABSOLUTE = 0x8000;
    private const uint MOUSEEVENTF_VIRTUALDESK = 0x4000;
    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP = 0x0004;

    // ========================================================
    // >> CORRIGIDO: Move o cursor com coordenadas em pixels <<
    // ========================================================
    public static void MoveAbsolute(double x, double y)
    {
        int screenW = GetSystemMetrics(0); // largura real da tela
        int screenH = GetSystemMetrics(1); // altura real da tela

        // Normaliza para 0–65535 conforme a proporção da tela
        int absX = (int)Math.Round((x / screenW) * 65535.0);
        int absY = (int)Math.Round((y / screenH) * 65535.0);

        // Evita que valores bugados travem o ponteiro
        absX = Math.Clamp(absX, 0, 65535);
        absY = Math.Clamp(absY, 0, 65535);

        INPUT[] input = new INPUT[1];
        input[0].type = INPUT_MOUSE;
        input[0].u.mi.dx = absX;
        input[0].u.mi.dy = absY;
        input[0].u.mi.mouseData = 0;
        input[0].u.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK;
        input[0].u.mi.time = 0;
        input[0].u.mi.dwExtraInfo = IntPtr.Zero;

        uint result = SendInput(1, input, INPUT.Size);
        Console.WriteLine($"[DEBUG] MoveAbsolute: X={x:F1}, Y={y:F1} → absX={absX}, absY={absY}, result={result}");
    }

    // ========================================================
    // >> Clique esquerdo <<
    // ========================================================
    public static void MouseDown()
    {
        INPUT[] input = new INPUT[1];
        input[0].type = INPUT_MOUSE;
        input[0].u.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        uint result = SendInput(1, input, INPUT.Size);
        Console.WriteLine($"[DEBUG] MouseDown → result={result}");
    }

    public static void MouseUp()
    {
        INPUT[] input = new INPUT[1];
        input[0].type = INPUT_MOUSE;
        input[0].u.mi.dwFlags = MOUSEEVENTF_LEFTUP;
        uint result = SendInput(1, input, INPUT.Size);
        Console.WriteLine($"[DEBUG] MouseUp → result={result}");
    }

    // ========================================================
    // >> Teclado (Z, X, C, V etc.) <<
    // ========================================================
    public static void SendKey(byte vk, bool down)
    {
        INPUT[] input = new INPUT[1];
        input[0].type = INPUT_KEYBOARD;
        input[0].u.ki.wVk = vk;
        input[0].u.ki.wScan = 0;
        input[0].u.ki.dwFlags = down ? 0u : KEYEVENTF_KEYUP;
        input[0].u.ki.time = 0;
        input[0].u.ki.dwExtraInfo = IntPtr.Zero;

        uint result = SendInput(1, input, INPUT.Size);
        Console.WriteLine($"[DEBUG] SendKey: vk={vk} down={down} → result={result}");
    }

    // ========================================================
    // >> Conversão de caractere para código de tecla <<
    // ========================================================
    public static byte VkFromLetter(char c)
    {
        return (byte)char.ToUpper(c);
    }
    public static int GetScreenWidth()
    {
        return GetSystemMetrics(0);
    }

    public static int GetScreenHeight()
    {
        return GetSystemMetrics(1);
    }

}
