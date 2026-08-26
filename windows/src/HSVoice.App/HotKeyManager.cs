using System.Runtime.InteropServices;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>
/// 低レベルキーボードフック(WH_KEYBOARD_LL)によるグローバルホットキー監視。
/// macOS版 GlobalHotKeyManager(CGEventTap)の対応物。
///
/// - 右Ctrl: 押下/解放をそのまま通知する。キーは飲み込まない(単独の右Ctrlに副作用はないため)。
/// - Ctrl+Space系: 発火したSpaceのdown/upは飲み込み、入力先アプリへ余計なスペースを入れない。
/// - 録音中のEsc: 飲み込んでキャンセルとして通知する。
///
/// フックのコールバックはメッセージループを持つスレッド(UIスレッド)で呼ばれる。
/// 処理は即座に返す必要がある — 遅いとWindowsがフックを外すことがある。
/// </summary>
public sealed class HotKeyManager : IDisposable
{
    private nint _hookHandle;
    private NativeMethods.LowLevelKeyboardProc? _hookProc; // GC防止のため保持
    private bool _activationKeyIsDown;
    private bool _swallowedSpace;

    public ShortcutChoice Shortcut { get; set; } = ShortcutChoice.RightControl;

    /// <summary>録音中だけEscを横取りするためのフラグ。AppModelが状態に応じて設定する。</summary>
    public bool CaptureEscape { get; set; }

    public event Action? ActivationPressed;
    public event Action? ActivationReleased;
    public event Action? EscapePressed;

    public void Install()
    {
        if (_hookHandle != 0) return;
        _hookProc = HookCallback;
        _hookHandle = NativeMethods.SetWindowsHookExW(
            NativeMethods.WH_KEYBOARD_LL, _hookProc, 0, 0);
        if (_hookHandle == 0)
        {
            throw new InvalidOperationException(
                $"キーボードフックを設定できませんでした (Win32 error {Marshal.GetLastWin32Error()})");
        }
    }

    public void Dispose()
    {
        if (_hookHandle != 0)
        {
            NativeMethods.UnhookWindowsHookEx(_hookHandle);
            _hookHandle = 0;
        }
        _hookProc = null;
    }

    private nint HookCallback(int nCode, nint wParam, nint lParam)
    {
        if (nCode < 0)
        {
            return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
        }

        var info = Marshal.PtrToStructure<NativeMethods.KBDLLHOOKSTRUCT>(lParam);
        var message = (int)wParam;
        var isDown = message is NativeMethods.WM_KEYDOWN or NativeMethods.WM_SYSKEYDOWN;
        var isUp = message is NativeMethods.WM_KEYUP or NativeMethods.WM_SYSKEYUP;

        // Escキャンセル: 録音中だけ横取りし、入力先アプリには渡さない。
        if (CaptureEscape && info.vkCode == NativeMethods.VK_ESCAPE)
        {
            if (isDown) EscapePressed?.Invoke();
            return 1;
        }

        if (Shortcut == ShortcutChoice.RightControl)
        {
            if (info.vkCode == NativeMethods.VK_RCONTROL)
            {
                if (isDown && !_activationKeyIsDown)
                {
                    _activationKeyIsDown = true;
                    ActivationPressed?.Invoke();
                }
                else if (isUp && _activationKeyIsDown)
                {
                    _activationKeyIsDown = false;
                    ActivationReleased?.Invoke();
                }
            }
            return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
        }

        // Ctrl+Space系ショートカット
        if (info.vkCode == NativeMethods.VK_SPACE)
        {
            if (isDown)
            {
                if (!_activationKeyIsDown && RequiredModifiersHeld())
                {
                    _activationKeyIsDown = true;
                    _swallowedSpace = true;
                    ActivationPressed?.Invoke();
                    return 1; // 入力先にスペースを入れない
                }
                if (_activationKeyIsDown)
                {
                    return 1; // キーリピートも飲み込む
                }
            }
            else if (isUp && _activationKeyIsDown)
            {
                _activationKeyIsDown = false;
                ActivationReleased?.Invoke();
                if (_swallowedSpace)
                {
                    _swallowedSpace = false;
                    return 1;
                }
            }
        }
        else if (isUp && _activationKeyIsDown && IsRequiredModifier(info.vkCode))
        {
            // 「押している間」モードで、Spaceより先に修飾キーが離された場合も解放とみなす。
            _activationKeyIsDown = false;
            ActivationReleased?.Invoke();
        }

        return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    private bool RequiredModifiersHeld()
    {
        var control = IsKeyDown(NativeMethods.VK_CONTROL);
        var shift = IsKeyDown(NativeMethods.VK_SHIFT);
        var alt = IsKeyDown(NativeMethods.VK_MENU);

        return Shortcut switch
        {
            ShortcutChoice.ControlSpace => control && !shift && !alt,
            ShortcutChoice.ControlShiftSpace => control && shift && !alt,
            ShortcutChoice.ControlAltSpace => control && alt && !shift,
            _ => false,
        };
    }

    private bool IsRequiredModifier(uint vkCode) => Shortcut switch
    {
        ShortcutChoice.ControlSpace =>
            vkCode is NativeMethods.VK_LCONTROL or NativeMethods.VK_RCONTROL,
        ShortcutChoice.ControlShiftSpace =>
            vkCode is NativeMethods.VK_LCONTROL or NativeMethods.VK_RCONTROL
                or 0xA0 or 0xA1, // VK_LSHIFT / VK_RSHIFT
        ShortcutChoice.ControlAltSpace =>
            vkCode is NativeMethods.VK_LCONTROL or NativeMethods.VK_RCONTROL
                or 0xA4 or 0xA5, // VK_LMENU / VK_RMENU
        _ => false,
    };

    private static bool IsKeyDown(int vkCode) =>
        (NativeMethods.GetAsyncKeyState(vkCode) & 0x8000) != 0;
}
