using System.Runtime.InteropServices;

namespace HSVoice.App;

/// <summary>Win32 P/Invoke。macOS版のCGEvent/Carbon/AXに相当する層。</summary>
internal static class NativeMethods
{
    // ── 仮想キーコード ──
    public const int VK_ESCAPE = 0x1B;
    public const int VK_SPACE = 0x20;
    public const int VK_LCONTROL = 0xA2;
    public const int VK_RCONTROL = 0xA3;
    public const int VK_CONTROL = 0x11;
    public const int VK_SHIFT = 0x10;
    public const int VK_MENU = 0x12; // Alt
    public const int VK_RETURN = 0x0D;
    public const int VK_Z = 0x5A;

    // ── 低レベルキーボードフック ──
    public const int WH_KEYBOARD_LL = 13;
    public const int WM_KEYDOWN = 0x0100;
    public const int WM_KEYUP = 0x0101;
    public const int WM_SYSKEYDOWN = 0x0104;
    public const int WM_SYSKEYUP = 0x0105;

    [StructLayout(LayoutKind.Sequential)]
    public struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public nint dwExtraInfo;
    }

    public delegate nint LowLevelKeyboardProc(int nCode, nint wParam, nint lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern nint SetWindowsHookExW(int idHook, LowLevelKeyboardProc lpfn, nint hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnhookWindowsHookEx(nint hhk);

    [DllImport("user32.dll")]
    public static extern nint CallNextHookEx(nint hhk, int nCode, nint wParam, nint lParam);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    // ── SendInput(Unicodeキーストローク合成) ──
    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint KEYEVENTF_UNICODE = 0x0004;

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public nint dwExtraInfo;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
        // MOUSEINPUT(28/32バイト)がKEYBDINPUTより大きいため、共用体のサイズを合わせる。
        [FieldOffset(0)] public MOUSEINPUT mi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public nint dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public INPUTUNION u;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint cInputs, INPUT[] pInputs, int cbSize);

    // ── 前面ウィンドウ管理(入力先の記憶と再前面化) ──
    [DllImport("user32.dll")]
    public static extern nint GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(nint hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindow(nint hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextW(nint hWnd, [Out] char[] lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(nint hWnd, out uint lpdwProcessId);

    // ── オーバーレイをフォーカスを奪わない道具ウィンドウにする ──
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_NOACTIVATE = 0x08000000;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int WS_EX_TRANSPARENT = 0x00000020;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern nint GetWindowLongPtrW(nint hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern nint SetWindowLongPtrW(nint hWnd, int nIndex, nint dwNewLong);
}
