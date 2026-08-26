using System.Text.Json;

namespace HSVoice.Core;

/// <summary>
/// オプトインのローカルテキスト履歴(既定は無効)。最大100件、新しい順。
/// %APPDATA%\HS Voice\history.json に保存。音声データは決して保存しない。
/// </summary>
public sealed class HistoryStore
{
    private readonly string _path;
    private readonly int _maximumEntries;
    private readonly List<HistoryEntry> _entries = new();
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public IReadOnlyList<HistoryEntry> Entries => _entries;

    public HistoryStore(string? path = null, int maximumEntries = 100)
    {
        _path = path ?? Path.Combine(SettingsStore.DefaultDirectory, "history.json");
        _maximumEntries = maximumEntries;
        Load();
    }

    public void Add(HistoryEntry entry)
    {
        _entries.Insert(0, entry);
        if (_entries.Count > _maximumEntries)
        {
            _entries.RemoveRange(_maximumEntries, _entries.Count - _maximumEntries);
        }
        Save();
    }

    public void Remove(Guid id)
    {
        _entries.RemoveAll(entry => entry.Id == id);
        Save();
    }

    public void Clear()
    {
        _entries.Clear();
        Save();
    }

    private void Load()
    {
        try
        {
            if (!File.Exists(_path)) return;
            var decoded = JsonSerializer.Deserialize<List<HistoryEntry>>(
                File.ReadAllText(_path), JsonOptions);
            if (decoded is null) return;
            _entries.Clear();
            _entries.AddRange(decoded.Take(_maximumEntries));
        }
        catch
        {
            _entries.Clear();
        }
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            File.WriteAllText(_path, JsonSerializer.Serialize(_entries, JsonOptions));
        }
        catch
        {
            // 履歴の保存失敗で入力機能を止めない。
        }
    }
}
