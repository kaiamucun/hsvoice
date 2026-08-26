using System.Text;

namespace HSVoice.Core;

/// <summary>
/// 社内サポート用の診断情報。入力本文・音声・個人情報は含めない(macOS版と同一方針)。
/// </summary>
public static class DiagnosticsReport
{
    public static string Build(
        string appVersion,
        SettingsData settings,
        string? modelPath,
        bool modelLoaded,
        string? lastErrorSummary)
    {
        var report = new StringBuilder();
        report.AppendLine("HS Voice for Windows 診断情報");
        report.AppendLine($"アプリバージョン: {appVersion}");
        report.AppendLine($"OS: {Environment.OSVersion.VersionString} ({(Environment.Is64BitOperatingSystem ? "64-bit" : "32-bit")})");
        report.AppendLine($"アーキテクチャ: {System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}");
        report.AppendLine($"論理プロセッサ数: {Environment.ProcessorCount}");
        report.AppendLine($"言語: {settings.LocaleIdentifier}");
        report.AppendLine($"ショートカット: {settings.ShortcutChoice.DisplayName()}");
        report.AppendLine($"録音方式: {settings.ActivationMode.Label()}");
        report.AppendLine($"入力方法: {settings.InsertionMode.ShortLabel()}");
        report.AppendLine($"音声コマンド: {(settings.SpokenFormattingCommands ? "有効" : "無効")}");
        report.AppendLine($"効果音: {(settings.SoundFeedback ? "有効" : "無効")}");
        report.AppendLine($"履歴: {(settings.KeepHistory ? "有効" : "無効")}");
        report.AppendLine($"辞書語数: {CountVocabulary(settings.CustomVocabulary)}");
        report.AppendLine($"モデル: {(modelPath is null ? "未検出" : Path.GetFileName(modelPath))}");
        report.AppendLine($"モデル読み込み: {(modelLoaded ? "完了" : "未完了")}");
        if (!string.IsNullOrEmpty(lastErrorSummary))
        {
            report.AppendLine($"直近のエラー: {lastErrorSummary}");
        }
        return report.ToString();
    }

    private static int CountVocabulary(string vocabulary) =>
        vocabulary
            .Split(new[] { '\n', '\r', ',', '、' }, StringSplitOptions.RemoveEmptyEntries)
            .Count(term => term.Trim().Length > 0);
}
