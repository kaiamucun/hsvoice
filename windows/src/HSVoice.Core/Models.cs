using System.Text.Json.Serialization;

namespace HSVoice.Core;

/// <summary>macOS版 Models.swift の対応物。状態機械と選択肢の定義。</summary>
public enum VoiceStateKind
{
    Idle,
    Listening,
    Processing,
    Success,
    Error,
}

public readonly record struct VoiceState(VoiceStateKind Kind, string? Message = null)
{
    public static readonly VoiceState Idle = new(VoiceStateKind.Idle);
    public static readonly VoiceState Listening = new(VoiceStateKind.Listening);
    public static readonly VoiceState Processing = new(VoiceStateKind.Processing);
    public static VoiceState Success(string message) => new(VoiceStateKind.Success, message);
    public static VoiceState Error(string message) => new(VoiceStateKind.Error, message);

    public bool IsBusy => Kind is VoiceStateKind.Listening or VoiceStateKind.Processing;

    public string Title => Kind switch
    {
        VoiceStateKind.Idle => "待機中",
        VoiceStateKind.Listening => "聞いています",
        VoiceStateKind.Processing => "仕上げています",
        VoiceStateKind.Success => "入力しました",
        VoiceStateKind.Error => "確認が必要です",
        _ => "",
    };
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum ActivationMode
{
    Hold,
    Toggle,
}

public static class ActivationModeExtensions
{
    public static string Label(this ActivationMode mode) => mode switch
    {
        ActivationMode.Hold => "押している間",
        ActivationMode.Toggle => "押すたびに開始・停止",
        _ => "",
    };
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum InsertionMode
{
    Automatic,
    ClipboardOnly,
}

public static class InsertionModeExtensions
{
    public static string Label(this InsertionMode mode) => mode switch
    {
        InsertionMode.Automatic => "カーソル位置へ自動入力",
        InsertionMode.ClipboardOnly => "クリップボードへコピーのみ",
        _ => "",
    };

    public static string ShortLabel(this InsertionMode mode) => mode switch
    {
        InsertionMode.Automatic => "自動入力",
        InsertionMode.ClipboardOnly => "コピーのみ",
        _ => "",
    };

    public static string Detail(this InsertionMode mode) => mode switch
    {
        InsertionMode.Automatic =>
            "録音前に使っていたアプリのカーソル位置へ直接入力します。クリップボードは使いません。",
        InsertionMode.ClipboardOnly =>
            "自動入力を行わず、認識結果をクリップボードへ残します。",
        _ => "",
    };
}

/// <summary>
/// Windows版のショートカット選択肢。fnキーはWindowsではキーボード内部で処理され
/// OSに届かないため存在しない。既定は右Ctrl(単独押しの副作用がなく、JIS/USどちらにもある)。
/// Win+HはWindows標準音声入力と衝突するため候補にしない。
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum ShortcutChoice
{
    RightControl,
    ControlSpace,
    ControlShiftSpace,
    ControlAltSpace,
}

public static class ShortcutChoiceExtensions
{
    public static string[] KeyLabels(this ShortcutChoice choice) => choice switch
    {
        ShortcutChoice.RightControl => new[] { "右Ctrl" },
        ShortcutChoice.ControlSpace => new[] { "Ctrl", "Space" },
        ShortcutChoice.ControlShiftSpace => new[] { "Ctrl", "Shift", "Space" },
        ShortcutChoice.ControlAltSpace => new[] { "Ctrl", "Alt", "Space" },
        _ => Array.Empty<string>(),
    };

    public static string DisplayName(this ShortcutChoice choice) =>
        string.Join(" + ", choice.KeyLabels());
}

public sealed record VoiceLocale(string Identifier, string DisplayName, string NativeName)
{
    /// <summary>
    /// macOS版と同じ言語リスト。identifierはBCP-47のまま保存し、
    /// whisperへ渡すときは先頭2文字の言語コードに変換する。
    /// </summary>
    public static readonly IReadOnlyList<VoiceLocale> Recommended = new List<VoiceLocale>
    {
        new("ja-JP", "Japanese", "日本語"),
        new("en-US", "English (US)", "English (US)"),
        new("en-GB", "English (UK)", "English (UK)"),
        new("zh-CN", "Chinese (Simplified)", "简体中文"),
        new("zh-TW", "Chinese (Traditional)", "繁體中文"),
        new("ko-KR", "Korean", "한국어"),
        new("fr-FR", "French", "Français"),
        new("de-DE", "German", "Deutsch"),
        new("es-ES", "Spanish", "Español"),
        new("it-IT", "Italian", "Italiano"),
        new("pt-BR", "Portuguese (Brazil)", "Português (Brasil)"),
    };

    /// <summary>"ja-JP" → "ja"。whisperの言語指定に使う。</summary>
    public string WhisperLanguageCode =>
        Identifier.Length >= 2 ? Identifier[..2].ToLowerInvariant() : "auto";
}

public sealed record HistoryEntry(
    Guid Id,
    DateTimeOffset CreatedAt,
    string Text,
    string? ApplicationName,
    string LocaleIdentifier)
{
    public static HistoryEntry Create(string text, string? applicationName, string localeIdentifier) =>
        new(Guid.NewGuid(), DateTimeOffset.Now, text, applicationName, localeIdentifier);
}

public enum TextInsertionOutcome
{
    Inserted,
    CopiedOnly,
    CopiedInsertionFailed,
}

public static class TextInsertionOutcomeExtensions
{
    public static string Message(this TextInsertionOutcome outcome) => outcome switch
    {
        TextInsertionOutcome.Inserted => "カーソル位置に入力しました",
        TextInsertionOutcome.CopiedOnly => "クリップボードにコピーしました",
        TextInsertionOutcome.CopiedInsertionFailed => "自動入力できなかったためコピーしました",
        _ => "",
    };
}

public static class RecordingLimit
{
    public static readonly TimeSpan MaximumDuration = TimeSpan.FromSeconds(55);
    public static readonly TimeSpan UndoAvailabilityDuration = TimeSpan.FromSeconds(8);

    /// <summary>残りがこの時間を切ると、経過時間表示がオレンジのカウントダウンに切り替わる。</summary>
    public static readonly TimeSpan CountdownWarningRemaining = TimeSpan.FromSeconds(10);
}
