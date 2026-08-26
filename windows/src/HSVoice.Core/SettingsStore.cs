using System.Text.Json;
using System.Text.Json.Serialization;

namespace HSVoice.Core;

/// <summary>
/// %APPDATA%\HS Voice\settings.json へのJSON永続化。
/// macOS版 SettingsStore.swift と同じ既定値: 日本語・押している間・自動入力・履歴オフ。
/// 利用者が言語やショートカットを選んでから使い始める必要はない。
/// </summary>
public sealed class SettingsData
{
    public string LocaleIdentifier { get; set; } = "ja-JP";
    public bool KeepHistory { get; set; } = false;
    public ActivationMode ActivationMode { get; set; } = ActivationMode.Hold;
    public InsertionMode InsertionMode { get; set; } = InsertionMode.Automatic;
    public bool InsertionModeChoiceFinalized { get; set; } = false;
    public ShortcutChoice ShortcutChoice { get; set; } = ShortcutChoice.RightControl;
    public string CustomVocabulary { get; set; } = "";
    public bool SpokenFormattingCommands { get; set; } = true;
    public bool SoundFeedback { get; set; } = true;
    public bool CompletedOnboarding { get; set; } = false;

    /// <summary>whisperモデルファイル(ggml形式)のパス。空なら既定の場所を探す。</summary>
    public string ModelPath { get; set; } = "";
}

public sealed class SettingsStore
{
    private readonly string _path;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    public SettingsData Data { get; private set; }

    public event Action? Changed;

    public SettingsStore(string? path = null)
    {
        _path = path ?? Path.Combine(DefaultDirectory, "settings.json");
        Data = Load();
    }

    public static string DefaultDirectory =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "HS Voice");

    /// <summary>カスタム辞書。改行・カンマ・読点区切り、最大100語(macOS版と同一仕様)。</summary>
    public IReadOnlyList<string> VocabularyTerms =>
        Data.CustomVocabulary
            .Split(new[] { '\n', '\r', ',', '、' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(term => term.Trim())
            .Where(term => term.Length > 0)
            .Take(100)
            .ToList();

    /// <summary>利用者による明示的な選択として挿入モードを記録する。</summary>
    public void SetInsertionMode(InsertionMode mode)
    {
        Data.InsertionMode = mode;
        Data.InsertionModeChoiceFinalized = true;
        Save();
    }

    public void Update(Action<SettingsData> mutate)
    {
        mutate(Data);
        Save();
    }

    /// <summary>
    /// 既定モデルの探索順: 設定パス → アプリフォルダのmodels\ → %APPDATA%\HS Voice\models\。
    /// </summary>
    public string? ResolveModelPath(string appBaseDirectory)
    {
        if (!string.IsNullOrWhiteSpace(Data.ModelPath) && File.Exists(Data.ModelPath))
        {
            return Data.ModelPath;
        }

        var candidates = new[]
        {
            Path.Combine(appBaseDirectory, "models"),
            Path.Combine(DefaultDirectory, "models"),
        };
        foreach (var directory in candidates)
        {
            if (!Directory.Exists(directory)) continue;
            var model = Directory.EnumerateFiles(directory, "ggml-*.bin")
                .OrderByDescending(File.GetLastWriteTimeUtc)
                .FirstOrDefault();
            if (model is not null) return model;
        }
        return null;
    }

    private SettingsData Load()
    {
        try
        {
            if (File.Exists(_path))
            {
                var loaded = JsonSerializer.Deserialize<SettingsData>(
                    File.ReadAllText(_path), JsonOptions);
                if (loaded is not null) return loaded;
            }
        }
        catch
        {
            // 壊れた設定ファイルは既定値で置き換える。設定の読み込み失敗でアプリを止めない。
        }
        return new SettingsData();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            File.WriteAllText(_path, JsonSerializer.Serialize(Data, JsonOptions));
            Changed?.Invoke();
        }
        catch
        {
            // ディスク書き込み失敗は動作継続を優先(次回保存で回復する)。
        }
    }
}
