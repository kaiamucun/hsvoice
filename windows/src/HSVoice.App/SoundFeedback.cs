using System.IO;
using System.Media;

namespace HSVoice.App;

/// <summary>
/// 開始・終了の短い効果音。外部ファイルに依存せず、起動時にサイン波のWAVを
/// メモリ上で合成する(設定でオフ可 — macOS版と同一仕様)。
/// </summary>
public sealed class SoundFeedback : IDisposable
{
    private readonly SoundPlayer _startSound;
    private readonly SoundPlayer _stopSound;
    private readonly SoundPlayer _errorSound;

    public bool Enabled { get; set; } = true;

    public SoundFeedback()
    {
        _startSound = new SoundPlayer(BuildTone(880, 0.09, 0.18));
        _stopSound = new SoundPlayer(BuildTone(587, 0.09, 0.18));
        _errorSound = new SoundPlayer(BuildTone(220, 0.16, 0.2));
        _startSound.Load();
        _stopSound.Load();
        _errorSound.Load();
    }

    public void PlayStart() { if (Enabled) TryPlay(_startSound); }
    public void PlayStop() { if (Enabled) TryPlay(_stopSound); }
    public void PlayError() { if (Enabled) TryPlay(_errorSound); }

    private static void TryPlay(SoundPlayer player)
    {
        try { player.Play(); }
        catch { /* 効果音の失敗は入力機能に影響させない */ }
    }

    /// <summary>フェードアウト付き単音のWAV(16kHz/16bit/モノラル)をメモリ上に生成する。</summary>
    private static Stream BuildTone(double frequency, double durationSeconds, double amplitude)
    {
        const int sampleRate = 16000;
        var sampleCount = (int)(sampleRate * durationSeconds);
        var dataSize = sampleCount * 2;

        var stream = new MemoryStream();
        using (var writer = new BinaryWriter(stream, System.Text.Encoding.ASCII, leaveOpen: true))
        {
            writer.Write("RIFF"u8);
            writer.Write(36 + dataSize);
            writer.Write("WAVE"u8);
            writer.Write("fmt "u8);
            writer.Write(16);
            writer.Write((short)1);           // PCM
            writer.Write((short)1);           // モノラル
            writer.Write(sampleRate);
            writer.Write(sampleRate * 2);     // byte rate
            writer.Write((short)2);           // block align
            writer.Write((short)16);          // bits per sample
            writer.Write("data"u8);
            writer.Write(dataSize);

            for (var i = 0; i < sampleCount; i++)
            {
                var progress = (double)i / sampleCount;
                var envelope = Math.Min(1.0, (1.0 - progress) * 4) * Math.Min(1.0, progress * 20);
                var value = Math.Sin(2 * Math.PI * frequency * i / sampleRate)
                    * amplitude * envelope;
                writer.Write((short)(value * short.MaxValue));
            }
        }
        stream.Position = 0;
        return stream;
    }

    public void Dispose()
    {
        _startSound.Dispose();
        _stopSound.Dispose();
        _errorSound.Dispose();
    }
}
