using System.Diagnostics;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>入力先(録音開始時の前面ウィンドウ)。macOS版 AppTarget の対応物。</summary>
public sealed record InsertionTarget(nint WindowHandle, string? ApplicationName)
{
    public bool IsAlive => NativeMethods.IsWindow(WindowHandle);
}

/// <summary>
/// SendInput(KEYEVENTF_UNICODE)によるキーストローク合成でテキストを挿入する。
/// macOS版 TextInsertionService(CGEvent)の対応物。
///
/// 成功経路ではクリップボードに決して触れない — クリップボードへの書き込みは、
/// 挿入が実行できないときに文字起こしを失わせないための意図的なフォールバックのみ。
///
/// 既知の制約(Windows固有):
/// - 管理者権限で実行中のアプリへは、通常権限のHS Voiceからは入力を送れない(UIPI)。
/// - 一部のセキュリティ系アプリは合成キー入力をブロックする。
/// どちらもクリップボードへのフォールバックで文字起こし自体は残る。
/// </summary>
public sealed class TextInsertionService
{
    /// <summary>
    /// 1回のSendInputで送るUTF-16ユニット数。長い文字起こしはチャンクに分けて、
    /// 遅いイベントキュー(Electron系など)でも文字を落とさないようにする。
    /// </summary>
    private const int TypingChunkLength = 20;

    /// <summary>現在の前面ウィンドウを入力先として捕捉する(録音開始時に呼ぶ)。</summary>
    public InsertionTarget? CurrentTarget()
    {
        var handle = NativeMethods.GetForegroundWindow();
        if (handle == 0) return null;

        // 自プロセスのウィンドウ(設定画面など)は入力先にしない。
        NativeMethods.GetWindowThreadProcessId(handle, out var processId);
        if (processId == Environment.ProcessId) return null;

        return new InsertionTarget(handle, ApplicationNameOf(processId));
    }

    public async Task<TextInsertionOutcome> InsertAsync(string text, InsertionTarget? target)
    {
        if (target is null || !target.IsAlive)
        {
            return CopyToClipboard(text, TextInsertionOutcome.CopiedOnly);
        }

        // HS Voiceはトレイ常駐でフォーカスを取らないため、入力先はほぼ常に前面のまま。
        // その一般的な場合は前面化の往復を省き、話し終えてから文字が見えるまでの遅延を削る。
        bool neededActivation;
        if (NativeMethods.GetForegroundWindow() == target.WindowHandle)
        {
            neededActivation = false;
        }
        else
        {
            if (!await ActivateAsync(target).ConfigureAwait(true))
            {
                return CopyToClipboard(text, TextInsertionOutcome.CopiedOnly);
            }
            neededActivation = true;
        }

        var settleDelay = neededActivation
            ? Timing.InsertionSettleDelayAfterActivation
            : Timing.InsertionSettleDelay;
        await Task.Delay(settleDelay).ConfigureAwait(true);

        if (!await TypeUnicodeAsync(text).ConfigureAwait(true))
        {
            return CopyToClipboard(text, TextInsertionOutcome.CopiedInsertionFailed);
        }
        return TextInsertionOutcome.Inserted;
    }

    /// <summary>
    /// 挿入直後8秒間の安全な取り消し。入力先がまだ前面にある場合のみCtrl+Zを送る
    /// (macOS版のCmd+Zと同一仕様: 別のアプリへ取り消しを撃ち込まない)。
    /// </summary>
    public bool Undo(InsertionTarget? target)
    {
        if (target is null || !target.IsAlive) return false;
        if (NativeMethods.GetForegroundWindow() != target.WindowHandle) return false;

        var inputs = new[]
        {
            KeyEvent(NativeMethods.VK_CONTROL, up: false),
            KeyEvent(NativeMethods.VK_Z, up: false),
            KeyEvent(NativeMethods.VK_Z, up: true),
            KeyEvent(NativeMethods.VK_CONTROL, up: true),
        };
        return Send(inputs);
    }

    private static async Task<bool> ActivateAsync(InsertionTarget target)
    {
        NativeMethods.SetForegroundWindow(target.WindowHandle);
        var deadline = DateTime.UtcNow + Timing.ActivationTimeout;
        while (DateTime.UtcNow < deadline)
        {
            if (NativeMethods.GetForegroundWindow() == target.WindowHandle) return true;
            await Task.Delay(Timing.ActivationPollInterval).ConfigureAwait(true);
        }
        return false;
    }

    /// <summary>
    /// テキストをUnicodeペイロード付きの合成キーボードイベントとして送出する。
    /// チャンクはサロゲートペアを決して分割せず、改行はVK_RETURNの実キーとして送る
    /// (KEYEVENTF_UNICODEの改行文字は無視するアプリがあるため)。
    /// KEYEVENTF_UNICODEはIMEを経由しないので、日本語IMEの変換状態を汚さない。
    /// </summary>
    private static async Task<bool> TypeUnicodeAsync(string text)
    {
        var normalized = text.Replace("\r\n", "\n");
        var index = 0;
        while (index < normalized.Length)
        {
            if (normalized[index] == '\n')
            {
                var enter = new[]
                {
                    KeyEvent(NativeMethods.VK_RETURN, up: false),
                    KeyEvent(NativeMethods.VK_RETURN, up: true),
                };
                if (!Send(enter)) return false;
                index++;
            }
            else
            {
                var chunkEnd = Math.Min(index + TypingChunkLength, normalized.Length);
                var newline = normalized.IndexOf('\n', index, chunkEnd - index);
                if (newline >= 0) chunkEnd = newline;
                // サロゲートペアの真ん中で切らない。
                if (chunkEnd < normalized.Length && chunkEnd > index
                    && char.IsHighSurrogate(normalized[chunkEnd - 1]))
                {
                    chunkEnd--;
                }
                if (chunkEnd == index) { index++; continue; }

                var inputs = new NativeMethods.INPUT[(chunkEnd - index) * 2];
                var cursor = 0;
                for (var i = index; i < chunkEnd; i++)
                {
                    inputs[cursor++] = UnicodeEvent(normalized[i], up: false);
                    inputs[cursor++] = UnicodeEvent(normalized[i], up: true);
                }
                if (!Send(inputs)) return false;
                index = chunkEnd;
            }

            if (index < normalized.Length)
            {
                await Task.Delay(Timing.InsertionChunkInterval).ConfigureAwait(true);
            }
        }
        return true;
    }

    private static NativeMethods.INPUT UnicodeEvent(char unit, bool up) => new()
    {
        type = NativeMethods.INPUT_KEYBOARD,
        u = new NativeMethods.INPUTUNION
        {
            ki = new NativeMethods.KEYBDINPUT
            {
                wVk = 0,
                wScan = unit,
                dwFlags = NativeMethods.KEYEVENTF_UNICODE
                    | (up ? NativeMethods.KEYEVENTF_KEYUP : 0),
            },
        },
    };

    private static NativeMethods.INPUT KeyEvent(int virtualKey, bool up) => new()
    {
        type = NativeMethods.INPUT_KEYBOARD,
        u = new NativeMethods.INPUTUNION
        {
            ki = new NativeMethods.KEYBDINPUT
            {
                wVk = (ushort)virtualKey,
                dwFlags = up ? NativeMethods.KEYEVENTF_KEYUP : 0,
            },
        },
    };

    private static bool Send(NativeMethods.INPUT[] inputs)
    {
        var sent = NativeMethods.SendInput(
            (uint)inputs.Length, inputs,
            System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.INPUT>());
        return sent == inputs.Length;
    }

    private static TextInsertionOutcome CopyToClipboard(string text, TextInsertionOutcome outcome)
    {
        // クリップボードは他プロセスがロックしていることがあるため数回再試行する。
        for (var attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                System.Windows.Clipboard.SetDataObject(text, true);
                return outcome;
            }
            catch
            {
                Thread.Sleep(30);
            }
        }
        return outcome;
    }

    private static string? ApplicationNameOf(uint processId)
    {
        try
        {
            using var process = Process.GetProcessById((int)processId);
            return process.ProcessName;
        }
        catch
        {
            return null;
        }
    }
}
