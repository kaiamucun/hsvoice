namespace HSVoice.Core;

/// <summary>
/// 利用者が体感するすべての待ち時間を1箇所に集める(macOS版 Timing.swift の方針を踏襲)。
/// 「キーを離してから文字が見えるまで」の合計コストをここでレビューできるようにする。
/// </summary>
public static class Timing
{
    // ── 認識(whisper) ──

    /// <summary>
    /// 録音中の逐次(パーシャル)認識を新しい音声がこの長さ溜まるたびに実行する。
    /// whisperはチャンク推論なので、SpeechAnalyzerのような即時更新ではなく
    /// この間隔+推論時間ぶん遅れたライブ表示になる。
    /// </summary>
    public static readonly TimeSpan PartialInferenceInterval = TimeSpan.FromSeconds(1.2);

    /// <summary>パーシャル推論に渡す音声の最大長。長すぎると推論が録音に追いつかなくなる。</summary>
    public static readonly TimeSpan PartialWindowMaximum = TimeSpan.FromSeconds(22);

    /// <summary>最終認識のハードリミット。停止した推論に文字起こしを人質に取らせない。</summary>
    public static readonly TimeSpan FinalInferenceDeadline = TimeSpan.FromSeconds(30);

    // ── テキスト挿入 ──

    /// <summary>入力先アプリが前面に来るのを待つ間のポーリング間隔。</summary>
    public static readonly TimeSpan ActivationPollInterval = TimeSpan.FromMilliseconds(10);

    /// <summary>この時間で前面化を諦め、クリップボードへフォールバックする。</summary>
    public static readonly TimeSpan ActivationTimeout = TimeSpan.FromMilliseconds(350);

    /// <summary>入力先がずっと前面だった場合の、最初の合成キー入力前の整定待ち。</summary>
    public static readonly TimeSpan InsertionSettleDelay = TimeSpan.FromMilliseconds(20);

    /// <summary>アプリを切り替えた直後は、キーハンドラの用意ができるまで少し長く待つ。</summary>
    public static readonly TimeSpan InsertionSettleDelayAfterActivation = TimeSpan.FromMilliseconds(45);

    /// <summary>合成キー入力のチャンク間の休止。遅いイベントキューでも文字を落とさない速さ。</summary>
    public static readonly TimeSpan InsertionChunkInterval = TimeSpan.FromMilliseconds(4);

    // ── 録音UI ──

    public static readonly TimeSpan RecordingTick = TimeSpan.FromMilliseconds(250);
    public static readonly TimeSpan AudioLevelUpdateInterval = TimeSpan.FromMilliseconds(50);
    public const double AudioLevelSignificantChange = 0.02;

    // ── ステータス復帰 ──

    public static readonly TimeSpan SuccessResetDelay = TimeSpan.FromSeconds(1.6);
    public static readonly TimeSpan ErrorResetDelay = TimeSpan.FromSeconds(2.4);
}
