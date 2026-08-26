using System.Windows;
using System.Windows.Controls;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>設定画面。開いたときの値の流し込み中はイベントを無視する(_loadingフラグ)。</summary>
public partial class SettingsWindow : Window
{
    private readonly AppModel _model;
    private bool _loading = true;

    public SettingsWindow(AppModel model)
    {
        _model = model;
        InitializeComponent();
        Populate();
        _loading = false;
    }

    private void Populate()
    {
        LanguageBox.Items.Clear();
        foreach (var locale in VoiceLocale.Recommended)
        {
            LanguageBox.Items.Add(new ComboBoxItem
            {
                Content = locale.NativeName,
                Tag = locale.Identifier,
            });
        }
        SelectByTag(LanguageBox, _model.Settings.Data.LocaleIdentifier);

        ShortcutBox.Items.Clear();
        foreach (var choice in Enum.GetValues<ShortcutChoice>())
        {
            ShortcutBox.Items.Add(new ComboBoxItem
            {
                Content = choice.DisplayName(),
                Tag = choice.ToString(),
            });
        }
        SelectByTag(ShortcutBox, _model.Settings.Data.ShortcutChoice.ToString());

        HoldRadio.IsChecked = _model.Settings.Data.ActivationMode == ActivationMode.Hold;
        ToggleRadio.IsChecked = _model.Settings.Data.ActivationMode == ActivationMode.Toggle;
        AutomaticRadio.IsChecked = _model.Settings.Data.InsertionMode == InsertionMode.Automatic;
        ClipboardRadio.IsChecked = _model.Settings.Data.InsertionMode == InsertionMode.ClipboardOnly;
        VocabularyBox.Text = _model.Settings.Data.CustomVocabulary;
        SpokenCommandsCheck.IsChecked = _model.Settings.Data.SpokenFormattingCommands;
        SoundCheck.IsChecked = _model.Settings.Data.SoundFeedback;
        HistoryCheck.IsChecked = _model.Settings.Data.KeepHistory;
        LaunchCheck.IsChecked = StartupManager.IsEnabled;
        RefreshModelStatus();
        VersionText.Text = $"HS Voice for Windows {AppModel.AppVersion}";
    }

    private void RefreshModelStatus()
    {
        ModelStatus.Text = _model.ModelLoaded
            ? $"読み込み済み: {System.IO.Path.GetFileName(_model.ModelPath)}"
            : _model.ModelMissing
                ? "モデルが見つかりません。ファイルを選択するか、models フォルダへ配置してください。"
                : "読み込み中…";
    }

    private static void SelectByTag(ComboBox box, string tag)
    {
        foreach (ComboBoxItem item in box.Items)
        {
            if ((string)item.Tag == tag)
            {
                box.SelectedItem = item;
                return;
            }
        }
    }

    private void OnLanguageChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loading || LanguageBox.SelectedItem is not ComboBoxItem item) return;
        _model.Settings.Update(data => data.LocaleIdentifier = (string)item.Tag);
        _model.ApplySettingsChange();
    }

    private void OnShortcutChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loading || ShortcutBox.SelectedItem is not ComboBoxItem item) return;
        _model.Settings.Update(data =>
            data.ShortcutChoice = Enum.Parse<ShortcutChoice>((string)item.Tag));
        _model.ApplySettingsChange();
    }

    private void OnActivationChanged(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _model.Settings.Update(data => data.ActivationMode =
            HoldRadio.IsChecked == true ? ActivationMode.Hold : ActivationMode.Toggle);
        _model.ApplySettingsChange();
    }

    private void OnInsertionChanged(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _model.Settings.SetInsertionMode(
            AutomaticRadio.IsChecked == true
                ? InsertionMode.Automatic
                : InsertionMode.ClipboardOnly);
        _model.ApplySettingsChange();
    }

    private void OnVocabularyChanged(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _model.Settings.Update(data => data.CustomVocabulary = VocabularyBox.Text);
    }

    private void OnBehaviorChanged(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _model.Settings.Update(data =>
        {
            data.SpokenFormattingCommands = SpokenCommandsCheck.IsChecked == true;
            data.SoundFeedback = SoundCheck.IsChecked == true;
            data.KeepHistory = HistoryCheck.IsChecked == true;
        });
        _model.ApplySettingsChange();
    }

    private void OnLaunchChanged(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        var error = StartupManager.SetEnabled(LaunchCheck.IsChecked == true);
        if (error is not null)
        {
            MessageBox.Show(this, $"ログイン時起動を変更できませんでした: {error}",
                "HS Voice", MessageBoxButton.OK, MessageBoxImage.Warning);
            _loading = true;
            LaunchCheck.IsChecked = StartupManager.IsEnabled;
            _loading = false;
        }
    }

    private void OnClearHistory(object sender, RoutedEventArgs e)
    {
        _model.History.Clear();
    }

    private void OnBrowseModel(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.OpenFileDialog
        {
            Filter = "whisperモデル (ggml-*.bin)|*.bin|すべてのファイル|*.*",
            Title = "whisperモデルファイルを選択",
        };
        if (dialog.ShowDialog(this) == true)
        {
            _model.Settings.Update(data => data.ModelPath = dialog.FileName);
            _ = ReloadModelAndRefreshAsync();
        }
    }

    private async void OnDownloadModel(object sender, RoutedEventArgs e)
    {
        DownloadModelButton.IsEnabled = false;
        ModelDownloadProgress.Visibility = Visibility.Visible;
        var progress = new Progress<double>(value =>
        {
            ModelDownloadProgress.Value = value;
            ModelStatus.Text = $"ダウンロード中… {value:P0}";
        });
        try
        {
            var path = await new ModelDownloader().DownloadAsync(
                ModelChoice.Available[0], progress, CancellationToken.None);
            _model.Settings.Update(data => data.ModelPath = path);
            await ReloadModelAndRefreshAsync();
        }
        catch (Exception error)
        {
            ModelStatus.Text = $"ダウンロードに失敗しました: {error.Message}";
        }
        finally
        {
            DownloadModelButton.IsEnabled = true;
            ModelDownloadProgress.Visibility = Visibility.Collapsed;
        }
    }

    private void OnReloadModel(object sender, RoutedEventArgs e)
    {
        _ = ReloadModelAndRefreshAsync();
    }

    private async Task ReloadModelAndRefreshAsync()
    {
        ModelStatus.Text = "読み込み中…";
        await _model.ReloadModelAsync();
        RefreshModelStatus();
    }

    private void OnCopyDiagnostics(object sender, RoutedEventArgs e)
    {
        var report = DiagnosticsReport.Build(
            AppModel.AppVersion,
            _model.Settings.Data,
            _model.ModelPath,
            _model.ModelLoaded,
            _model.LastErrorSummary);
        try
        {
            Clipboard.SetDataObject(report, true);
        }
        catch { /* クリップボードのロックは無視 */ }
    }
}
