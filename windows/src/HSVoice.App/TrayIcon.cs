using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>
/// タスクトレイ常駐(macOS版メニューバー常駐の対応物)。
/// 設定画面へ移動せずに、言語と入力方法をその場で切り替えられる。
/// アイコンは外部アセットに依存せず実行時に描画する。
/// </summary>
public sealed class TrayIcon : IDisposable
{
    private readonly AppModel _model;
    private readonly Action _openSettings;
    private readonly Action _openHistory;
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _idleIcon;
    private readonly Icon _activeIcon;

    private readonly ToolStripMenuItem _statusItem = new() { Enabled = false };
    private readonly ToolStripMenuItem _languageMenu = new("話す言語");
    private readonly ToolStripMenuItem _insertionMenu = new("入力方法");
    private readonly ToolStripMenuItem _reinsertItem = new("もう一度入力");
    private readonly ToolStripMenuItem _copyItem = new("コピー");
    private readonly ToolStripMenuItem _undoItem = new("直前の入力を取り消す");

    public TrayIcon(AppModel model, Action openSettings, Action openHistory)
    {
        _model = model;
        _openSettings = openSettings;
        _openHistory = openHistory;
        _idleIcon = DrawIcon(active: false);
        _activeIcon = DrawIcon(active: true);

        var menu = new ContextMenuStrip();
        menu.Items.Add(_statusItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(_languageMenu);
        menu.Items.Add(_insertionMenu);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(_reinsertItem);
        menu.Items.Add(_copyItem);
        menu.Items.Add(_undoItem);
        menu.Items.Add(new ToolStripSeparator());
        var historyItem = new ToolStripMenuItem("履歴…");
        historyItem.Click += (_, _) => _openHistory();
        menu.Items.Add(historyItem);
        var settingsItem = new ToolStripMenuItem("設定…");
        settingsItem.Click += (_, _) => _openSettings();
        menu.Items.Add(settingsItem);
        var quitItem = new ToolStripMenuItem("HS Voice を終了");
        quitItem.Click += (_, _) => System.Windows.Application.Current.Shutdown();
        menu.Items.Add(quitItem);
        menu.Opening += (_, _) => RefreshMenu();

        _reinsertItem.Click += async (_, _) => await _model.ReinsertLastAsync();
        _copyItem.Click += (_, _) => _model.CopyLastToClipboard();
        _undoItem.Click += (_, _) => _model.UndoLastInsertion();

        BuildLanguageMenu();
        BuildInsertionMenu();

        _notifyIcon = new NotifyIcon
        {
            Icon = _idleIcon,
            Text = "HS Voice",
            Visible = true,
            ContextMenuStrip = menu,
        };
        _notifyIcon.DoubleClick += (_, _) => _openSettings();
    }

    public void Refresh()
    {
        _notifyIcon.Icon = _model.State.IsBusy ? _activeIcon : _idleIcon;
        var shortcut = _model.Settings.Data.ShortcutChoice.DisplayName();
        _notifyIcon.Text = _model.State.Kind == VoiceStateKind.Idle
            ? $"HS Voice — {shortcut} で話す"
            : $"HS Voice — {_model.State.Title}";
    }

    private void RefreshMenu()
    {
        _statusItem.Text = _model.State.Kind == VoiceStateKind.Idle
            ? $"{_model.Settings.Data.ShortcutChoice.DisplayName()} を押して話す"
            : _model.State.Title;

        foreach (ToolStripMenuItem item in _languageMenu.DropDownItems)
        {
            item.Checked = (string)item.Tag! == _model.Settings.Data.LocaleIdentifier;
        }
        foreach (ToolStripMenuItem item in _insertionMenu.DropDownItems)
        {
            item.Checked = (string)item.Tag! == _model.Settings.Data.InsertionMode.ToString();
        }

        var hasLastText = _model.LastText is not null;
        _reinsertItem.Enabled = hasLastText && !_model.State.IsBusy;
        _copyItem.Enabled = hasLastText;
        _undoItem.Enabled = _model.CanUndo;
    }

    private void BuildLanguageMenu()
    {
        foreach (var locale in VoiceLocale.Recommended)
        {
            var item = new ToolStripMenuItem(locale.NativeName) { Tag = locale.Identifier };
            item.Click += (_, _) =>
            {
                _model.Settings.Update(data => data.LocaleIdentifier = locale.Identifier);
                _model.ApplySettingsChange();
            };
            _languageMenu.DropDownItems.Add(item);
        }
    }

    private void BuildInsertionMenu()
    {
        foreach (var mode in Enum.GetValues<InsertionMode>())
        {
            var item = new ToolStripMenuItem(mode.Label()) { Tag = mode.ToString() };
            item.Click += (_, _) =>
            {
                _model.Settings.SetInsertionMode(mode);
                _model.ApplySettingsChange();
            };
            _insertionMenu.DropDownItems.Add(item);
        }
    }

    /// <summary>波形風の3本バーを描いた16/32px両対応のアイコンを生成する。</summary>
    private static Icon DrawIcon(bool active)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        var background = active
            ? Color.FromArgb(255, 90, 200, 250)
            : Color.FromArgb(255, 96, 96, 104);
        using (var brush = new SolidBrush(background))
        {
            graphics.FillEllipse(brush, 1, 1, 30, 30);
        }

        using var barBrush = new SolidBrush(Color.White);
        void Bar(int x, int height) =>
            graphics.FillRectangle(barBrush, x, 16 - height / 2, 4, height);
        Bar(7, 10);
        Bar(14, 18);
        Bar(21, 10);

        var handle = bitmap.GetHicon();
        try
        {
            using var temporary = Icon.FromHandle(handle);
            return (Icon)temporary.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool DestroyIcon(nint handle);

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _idleIcon.Dispose();
        _activeIcon.Dispose();
    }
}
