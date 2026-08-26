using System.Windows;
using System.Windows.Controls;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>
/// 初回起動ガイド(macOS版 OnboardingView の対応物)。
/// macOSと違いアクセシビリティ・音声認識の権限は不要なので、
/// 実質の必須手順は「モデルを1回ダウンロードする」だけ。
/// モデルが既に見つかっている(社内配布で同梱など)場合はダウンロードUIを畳む。
/// </summary>
public partial class OnboardingWindow : Window
{
    private readonly AppModel _model;
    private CancellationTokenSource? _downloadCancellation;

    public OnboardingWindow(AppModel model)
    {
        _model = model;
        InitializeComponent();

        foreach (var choice in ModelChoice.Available)
        {
            ModelChoiceBox.Items.Add(new ComboBoxItem
            {
                Content = choice.DisplayName,
                Tag = choice.Key,
            });
        }
        ModelChoiceBox.SelectedIndex = 0;
        _model.Changed += RefreshModelState; // 起動時の非同期モデル読み込み完了を反映
        UsageText.Text =
            $"テキスト欄へカーソルを置き、{_model.Settings.Data.ShortcutChoice.DisplayName()} を"
            + "押しながら話して、離すだけです。ショートカットや言語はタスクトレイのアイコンと設定画面からいつでも変更できます。";
        RefreshModelState();
    }

    private void RefreshModelState()
    {
        if (_model.ModelLoaded || !_model.ModelMissing)
        {
            ModelStatusText.Text = _model.ModelLoaded
                ? $"準備完了: {System.IO.Path.GetFileName(_model.ModelPath)}"
                : "モデルを確認しています…";
            var ready = _model.ModelLoaded;
            ModelChoiceBox.Visibility = ready ? Visibility.Collapsed : Visibility.Visible;
            DownloadButton.Visibility = ready ? Visibility.Collapsed : Visibility.Visible;
            BrowseButton.Visibility = ready ? Visibility.Collapsed : Visibility.Visible;
            StartButton.IsEnabled = ready;
        }
        else
        {
            ModelStatusText.Text = "音声認識モデルがまだありません。ダウンロードするか、ファイルを選択してください。";
            StartButton.IsEnabled = false;
        }
    }

    private async void OnDownload(object sender, RoutedEventArgs e)
    {
        var key = (ModelChoiceBox.SelectedItem as ComboBoxItem)?.Tag as string;
        var choice = ModelChoice.Available.FirstOrDefault(model => model.Key == key)
            ?? ModelChoice.Available[0];

        DownloadButton.IsEnabled = false;
        BrowseButton.IsEnabled = false;
        DownloadProgress.Visibility = Visibility.Visible;
        _downloadCancellation = new CancellationTokenSource();
        var progress = new Progress<double>(value =>
        {
            DownloadProgress.Value = value;
            ModelStatusText.Text = $"ダウンロード中… {value:P0}";
        });

        try
        {
            var path = await new ModelDownloader().DownloadAsync(
                choice, progress, _downloadCancellation.Token);
            _model.Settings.Update(data => data.ModelPath = path);
            ModelStatusText.Text = "モデルを読み込んでいます…";
            await _model.ReloadModelAsync();
        }
        catch (Exception error)
        {
            ModelStatusText.Text =
                $"ダウンロードに失敗しました: {error.Message}\n"
                + "社内プロキシ環境ではIT部門にお問い合わせください。モデルファイルを直接受け取り「選択」から指定することもできます。";
        }
        finally
        {
            DownloadButton.IsEnabled = true;
            BrowseButton.IsEnabled = true;
            DownloadProgress.Visibility = Visibility.Collapsed;
            RefreshModelState();
        }
    }

    private async void OnBrowse(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.OpenFileDialog
        {
            Filter = "whisperモデル (ggml-*.bin)|*.bin|すべてのファイル|*.*",
            Title = "whisperモデルファイルを選択",
        };
        if (dialog.ShowDialog(this) == true)
        {
            _model.Settings.Update(data => data.ModelPath = dialog.FileName);
            ModelStatusText.Text = "モデルを読み込んでいます…";
            await _model.ReloadModelAsync();
            RefreshModelState();
        }
    }

    private void OnStart(object sender, RoutedEventArgs e)
    {
        _model.Settings.Update(data => data.CompletedOnboarding = true);
        Close();
    }

    protected override void OnClosed(EventArgs e)
    {
        _model.Changed -= RefreshModelState;
        _downloadCancellation?.Cancel();
        base.OnClosed(e);
    }
}
