using System.Windows;
using System.Windows.Controls;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>
/// オプトイン履歴の一覧(macOS版 HistoryView の対応物)。
/// 再入力・コピー・個別削除・全消去ができる。
/// </summary>
public partial class HistoryWindow : Window
{
    private sealed record Row(HistoryEntry Entry)
    {
        public string CreatedAtText => Entry.CreatedAt.ToLocalTime().ToString("MM/dd HH:mm");
        public string? ApplicationName => Entry.ApplicationName;
        public string Preview
        {
            get
            {
                var flattened = Entry.Text.Replace("\n", " ");
                return flattened.Length <= 60 ? flattened : flattened[..60] + "…";
            }
        }
    }

    private readonly AppModel _model;

    public HistoryWindow(AppModel model)
    {
        _model = model;
        InitializeComponent();
        Reload();
    }

    private void Reload()
    {
        HistoryList.ItemsSource = _model.History.Entries.Select(entry => new Row(entry)).ToList();
        EmptyHint.Visibility = _model.History.Entries.Count == 0
            ? Visibility.Visible : Visibility.Collapsed;
        UpdateButtons();
    }

    private Row? Selected => HistoryList.SelectedItem as Row;

    private void OnSelectionChanged(object sender, SelectionChangedEventArgs e) => UpdateButtons();

    private void UpdateButtons()
    {
        var hasSelection = Selected is not null;
        ReinsertButton.IsEnabled = hasSelection && !_model.State.IsBusy;
        CopyButton.IsEnabled = hasSelection;
        DeleteButton.IsEnabled = hasSelection;
    }

    private async void OnReinsert(object sender, RoutedEventArgs e)
    {
        if (Selected is not { } row) return;
        // このウィンドウが前面のままだと自ウィンドウが入力先になってしまうため、
        // 先に隠して直前に使っていたアプリへフォーカスを返す。
        Hide();
        await Task.Delay(150);
        await _model.InsertTextAsync(row.Entry.Text);
        Close();
    }

    private void OnCopy(object sender, RoutedEventArgs e)
    {
        if (Selected is not { } row) return;
        try { Clipboard.SetDataObject(row.Entry.Text, true); }
        catch { /* クリップボードのロックは無視 */ }
    }

    private void OnDelete(object sender, RoutedEventArgs e)
    {
        if (Selected is not { } row) return;
        _model.History.Remove(row.Entry.Id);
        Reload();
    }

    private void OnClearAll(object sender, RoutedEventArgs e)
    {
        _model.History.Clear();
        Reload();
    }
}
