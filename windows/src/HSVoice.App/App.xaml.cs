using System.Windows;
using HSVoice.Core;

namespace HSVoice.App;

public partial class App : Application
{
    private static Mutex? _singleInstanceMutex;

    private AppModel? _model;
    private TrayIcon? _tray;
    private OverlayWindow? _overlay;
    private SettingsWindow? _settingsWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 二重起動防止(2つのキーボードフックが同じキーを取り合うのを避ける)。
        _singleInstanceMutex = new Mutex(true, @"Local\HSVoiceSingleInstance", out var isNew);
        if (!isNew)
        {
            MessageBox.Show("HS Voice はすでに起動しています。タスクトレイのアイコンをご確認ください。",
                "HS Voice", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        _model = new AppModel(Dispatcher);
        _overlay = new OverlayWindow();
        _tray = new TrayIcon(_model, OpenSettings, OpenHistory);

        _model.Changed += RenderAll;
        _model.AudioLevelChanged += level => _overlay?.RenderLevel(level);

        try
        {
            _model.Start();
        }
        catch (Exception error)
        {
            MessageBox.Show(
                $"起動に失敗しました: {error.Message}",
                "HS Voice", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown();
            return;
        }

        // 初回起動時はセットアップガイドを表示(モデルのダウンロードと使い方の案内)。
        if (!_model.Settings.Data.CompletedOnboarding)
        {
            new OnboardingWindow(_model).Show();
        }

        RenderAll();
    }

    private void RenderAll()
    {
        if (_model is null) return;

        _tray?.Refresh();

        if (_overlay is not null)
        {
            if (_model.State.Kind == VoiceStateKind.Idle)
            {
                _overlay.Hide();
            }
            else
            {
                _overlay.Render(_model);
                if (!_overlay.IsVisible)
                {
                    _overlay.Show();
                    _overlay.PositionNear(_model.TargetWindowHandle);
                }
            }
        }
    }

    private void OpenSettings()
    {
        if (_model is null) return;
        if (_settingsWindow is null || !_settingsWindow.IsLoaded)
        {
            _settingsWindow = new SettingsWindow(_model);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    private HistoryWindow? _historyWindow;

    private void OpenHistory()
    {
        if (_model is null) return;
        if (_historyWindow is null || !_historyWindow.IsLoaded)
        {
            _historyWindow = new HistoryWindow(_model);
            _historyWindow.Closed += (_, _) => _historyWindow = null;
        }
        _historyWindow.Show();
        _historyWindow.Activate();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray?.Dispose();
        _model?.Dispose();
        _singleInstanceMutex?.ReleaseMutex();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
