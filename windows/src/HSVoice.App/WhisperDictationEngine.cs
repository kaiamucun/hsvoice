using System.Text;
using HSVoice.Core;
using Whisper.net;

namespace HSVoice.App;

/// <summary>
/// whisper.cpp(Whisper.net経由)による完全ローカル音声認識。
/// macOS版 AnalyzerDictationEngine(SpeechAnalyzer)の対応物。
///
/// SpeechAnalyzerと違いwhisperはストリーミング認識ではないため、録音中の
/// ライブ表示は「録音バッファ全体(上限あり)をパーシャル推論し直す」ことで近似する。
/// 前回のパーシャルが走っている間は次を積まない — 推論が録音に追いつけない
/// マシンでは、ライブ表示の更新間隔が自然に伸びるだけで録音自体は劣化しない。
/// </summary>
public sealed class WhisperDictationEngine : IDisposable
{
    private WhisperFactory? _factory;
    private readonly object _loadLock = new();
    private volatile bool _partialInFlight;

    public string? ModelPath { get; private set; }
    public bool IsLoaded => _factory is not null;

    /// <summary>モデル読み込み。数百MBのファイルをmmapするため初回のみ数秒かかる。</summary>
    public Task EnsureLoadedAsync(string modelPath) => Task.Run(() =>
    {
        lock (_loadLock)
        {
            if (_factory is not null && ModelPath == modelPath) return;
            _factory?.Dispose();
            _factory = WhisperFactory.FromPath(modelPath);
            ModelPath = modelPath;
        }
    });

    /// <summary>
    /// 録音中のパーシャル認識。前回がまだ走っていればnullを返して何もしない。
    /// </summary>
    public async Task<string?> TranscribePartialAsync(
        float[] samples,
        string languageCode,
        string? prompt,
        CancellationToken cancellation)
    {
        if (_partialInFlight || samples.Length < AudioCapture.SampleRate / 2)
        {
            return null;
        }
        _partialInFlight = true;
        try
        {
            return await TranscribeAsync(samples, languageCode, prompt, cancellation)
                .ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            return null;
        }
        finally
        {
            _partialInFlight = false;
        }
    }

    /// <summary>最終認識。全サンプルを1回で処理する。</summary>
    public async Task<string> TranscribeAsync(
        float[] samples,
        string languageCode,
        string? prompt,
        CancellationToken cancellation)
    {
        var factory = _factory
            ?? throw new InvalidOperationException("音声認識モデルが読み込まれていません");

        return await Task.Run(async () =>
        {
            var builder = factory.CreateBuilder()
                .WithLanguage(languageCode);
            if (!string.IsNullOrWhiteSpace(prompt))
            {
                builder = builder.WithPrompt(prompt);
            }

            await using var processor = builder.Build();
            var text = new StringBuilder();
            await foreach (var segment in processor.ProcessAsync(samples, cancellation)
                .ConfigureAwait(false))
            {
                text.Append(segment.Text);
            }
            return text.ToString();
        }, cancellation).ConfigureAwait(false);
    }

    /// <summary>
    /// カスタム辞書をwhisperのinitial promptへ変換する。
    /// promptは「直前の文脈」として扱われるため、用語を並べるだけで
    /// 該当語の表記が誘導される(完全な保証はない — macOS版の辞書とは効き方が異なる)。
    /// </summary>
    public static string? BuildPrompt(IReadOnlyList<string> vocabularyTerms, string languageCode)
    {
        if (vocabularyTerms.Count == 0) return null;
        var separator = languageCode is "ja" or "zh" ? "、" : ", ";
        return string.Join(separator, vocabularyTerms);
    }

    public void Dispose()
    {
        _factory?.Dispose();
        _factory = null;
    }
}
