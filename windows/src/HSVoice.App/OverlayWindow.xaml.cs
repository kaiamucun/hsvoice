using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>
/// 録音中に作業中モニターの下端へ表示する最小限の1行オーバーレイ。
/// WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW でフォーカスを奪わず、タスクバーにも出ない。
/// </summary>
public partial class OverlayWindow : Window
{
    private static readonly Brush ListeningBrush =
        new SolidColorBrush(Color.FromRgb(0x5A, 0xC8, 0xFA));
    private static readonly Brush ProcessingBrush =
        new SolidColorBrush(Color.FromRgb(0xC0, 0x8A, 0xFF));
    private static readonly Brush SuccessBrush =
        new SolidColorBrush(Color.FromRgb(0x54, 0xD6, 0x8A));
    private static readonly Brush ErrorBrush =
        new SolidColorBrush(Color.FromRgb(0xFF, 0x6B, 0x6B));
    private static readonly Brush CountdownBrush =
        new SolidColorBrush(Color.FromRgb(0xFF, 0xA5, 0x40));
    private static readonly Brush TimerBrush =
        new SolidColorBrush(Color.FromRgb(0xBB, 0xBB, 0xBB));

    public OverlayWindow()
    {
        InitializeComponent();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        var handle = new WindowInteropHelper(this).Handle;
        var style = NativeMethods.GetWindowLongPtrW(handle, NativeMethods.GWL_EXSTYLE);
        NativeMethods.SetWindowLongPtrW(
            handle,
            NativeMethods.GWL_EXSTYLE,
            style | NativeMethods.WS_EX_NOACTIVATE | NativeMethods.WS_EX_TOOLWINDOW);
    }

    /// <summary>入力先ウィンドウのあるモニターの下端中央へ配置する(複数モニター対応)。</summary>
    public void PositionNear(nint targetWindowHandle)
    {
        var screen = targetWindowHandle != 0 && NativeMethods.IsWindow(targetWindowHandle)
            ? System.Windows.Forms.Screen.FromHandle(targetWindowHandle)
            : System.Windows.Forms.Screen.PrimaryScreen;
        if (screen is null) return;

        // 物理ピクセル → WPFのDIPへ変換(Per-Monitor DPI)。
        var source = PresentationSource.FromVisual(this);
        var toDip = source?.CompositionTarget?.TransformFromDevice
            ?? Matrix.Identity;

        var workArea = screen.WorkingArea;
        var topLeft = toDip.Transform(new Point(workArea.Left, workArea.Top));
        var bottomRight = toDip.Transform(new Point(workArea.Right, workArea.Bottom));

        UpdateLayout();
        Left = topLeft.X + ((bottomRight.X - topLeft.X) - ActualWidth) / 2;
        Top = bottomRight.Y - ActualHeight - 24;
    }

    public void Render(AppModel model)
    {
        StateTitle.Text = model.State.Title;
        LiveText.Text = model.State.Kind switch
        {
            VoiceStateKind.Listening => model.PartialText,
            VoiceStateKind.Success or VoiceStateKind.Error => model.State.Message ?? "",
            _ => "",
        };

        StateDot.Fill = model.State.Kind switch
        {
            VoiceStateKind.Listening => ListeningBrush,
            VoiceStateKind.Processing => ProcessingBrush,
            VoiceStateKind.Success => SuccessBrush,
            VoiceStateKind.Error => ErrorBrush,
            _ => ListeningBrush,
        };

        if (model.State.Kind == VoiceStateKind.Listening)
        {
            var remaining = model.Remaining;
            if (remaining <= RecordingLimit.CountdownWarningRemaining)
            {
                // 55秒の安全停止が不意打ちにならないよう、残り10秒からオレンジで数える。
                TimerText.Text = $"残り {Math.Max(0, (int)remaining.TotalSeconds)} 秒";
                TimerText.Foreground = CountdownBrush;
            }
            else
            {
                var elapsed = model.Elapsed;
                TimerText.Text = $"{(int)elapsed.TotalMinutes}:{elapsed.Seconds:00}";
                TimerText.Foreground = TimerBrush;
            }
        }
        else
        {
            TimerText.Text = "";
        }
    }

    public void RenderLevel(double level)
    {
        LevelBar.Width = 52 * Math.Clamp(level * 1.6, 0, 1);
    }
}
