namespace HSVoice.Core;

/// <summary>ダウンロード可能なwhisperモデルの定義。</summary>
public sealed record ModelChoice(
    string Key,
    string FileName,
    string DisplayName,
    long ApproximateBytes)
{
    public static readonly IReadOnlyList<ModelChoice> Available = new List<ModelChoice>
    {
        new("large-v3-turbo", "ggml-large-v3-turbo-q5_0.bin",
            "高精度(推奨)— 約574MB", 574_000_000),
        new("small", "ggml-small.bin",
            "軽量(低スペックPC向け)— 約466MB", 466_000_000),
        new("medium", "ggml-medium-q5_0.bin",
            "中間 — 約514MB", 514_000_000),
    };

    public string Url =>
        $"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{FileName}";
}

/// <summary>
/// アプリ内からのモデルダウンロード。%APPDATA%\HS Voice\models へ保存する。
/// 途中失敗で壊れたファイルが残らないよう、.partial へ書いてから最後に改名する。
/// </summary>
public sealed class ModelDownloader
{
    private static readonly HttpClient Client = new()
    {
        Timeout = Timeout.InfiniteTimeSpan, // 進捗ベースで管理(巨大ファイルのため)
    };

    public static string DefaultModelDirectory =>
        Path.Combine(SettingsStore.DefaultDirectory, "models");

    /// <summary>保存先のフルパスを返す。progressは0.0〜1.0。</summary>
    public async Task<string> DownloadAsync(
        ModelChoice model,
        IProgress<double>? progress,
        CancellationToken cancellation)
    {
        Directory.CreateDirectory(DefaultModelDirectory);
        var destination = Path.Combine(DefaultModelDirectory, model.FileName);
        if (File.Exists(destination))
        {
            progress?.Report(1.0);
            return destination;
        }

        var partial = destination + ".partial";
        try
        {
            using var response = await Client.GetAsync(
                model.Url, HttpCompletionOption.ResponseHeadersRead, cancellation)
                .ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            var totalBytes = response.Content.Headers.ContentLength
                ?? model.ApproximateBytes;

            await using (var source = await response.Content
                .ReadAsStreamAsync(cancellation).ConfigureAwait(false))
            await using (var target = File.Create(partial))
            {
                var buffer = new byte[1 << 16];
                long written = 0;
                int read;
                while ((read = await source.ReadAsync(buffer, cancellation)
                    .ConfigureAwait(false)) > 0)
                {
                    await target.WriteAsync(buffer.AsMemory(0, read), cancellation)
                        .ConfigureAwait(false);
                    written += read;
                    if (totalBytes > 0)
                    {
                        progress?.Report(Math.Min(1.0, (double)written / totalBytes));
                    }
                }
            }

            File.Move(partial, destination, overwrite: true);
            progress?.Report(1.0);
            return destination;
        }
        catch
        {
            try { File.Delete(partial); } catch { /* 掃除失敗は無視 */ }
            throw;
        }
    }
}
