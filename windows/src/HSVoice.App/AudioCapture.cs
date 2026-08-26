using HSVoice.Core;
using NAudio.Wave;

namespace HSVoice.App;

/// <summary>
/// 既定マイクからの16kHz・16bit・モノラル取り込み。whisperの入力仕様に合わせる。
/// 音声はメモリ上にのみ保持し、ディスクへは決して書かない(macOS版と同一方針)。
/// </summary>
public sealed class AudioCapture : IDisposable
{
    public const int SampleRate = 16000;

    private WaveInEvent? _waveIn;
    private readonly List<float> _samples = new(SampleRate * 60);
    private readonly object _lock = new();
    private DateTime _lastLevelReport = DateTime.MinValue;
    private double _lastReportedLevel;

    /// <summary>0.0〜1.0の入力レベル。UIスレッド以外から呼ばれる点に注意。</summary>
    public event Action<double>? LevelChanged;

    public event Action<string>? CaptureFailed;

    public bool IsCapturing { get; private set; }

    public TimeSpan CapturedDuration
    {
        get
        {
            lock (_lock)
            {
                return TimeSpan.FromSeconds((double)_samples.Count / SampleRate);
            }
        }
    }

    public void Start()
    {
        if (IsCapturing) return;
        lock (_lock)
        {
            _samples.Clear();
        }

        _waveIn = new WaveInEvent
        {
            WaveFormat = new WaveFormat(SampleRate, 16, 1),
            BufferMilliseconds = 30,
        };
        _waveIn.DataAvailable += OnDataAvailable;
        _waveIn.RecordingStopped += OnRecordingStopped;
        _waveIn.StartRecording();
        IsCapturing = true;
    }

    public void Stop()
    {
        if (!IsCapturing) return;
        IsCapturing = false;
        try
        {
            _waveIn?.StopRecording();
        }
        catch
        {
            // 停止時の例外はサンプル確定を妨げない。
        }
    }

    /// <summary>現在までの全サンプルのコピー。</summary>
    public float[] SnapshotAll()
    {
        lock (_lock)
        {
            return _samples.ToArray();
        }
    }

    /// <summary>末尾から最大 maxDuration ぶんのサンプルのコピー(パーシャル認識用)。</summary>
    public float[] SnapshotTail(TimeSpan maxDuration)
    {
        lock (_lock)
        {
            var maxCount = (int)(maxDuration.TotalSeconds * SampleRate);
            var start = Math.Max(0, _samples.Count - maxCount);
            return _samples.GetRange(start, _samples.Count - start).ToArray();
        }
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs args)
    {
        var count = args.BytesRecorded / 2;
        var peak = 0f;
        lock (_lock)
        {
            for (var i = 0; i < count; i++)
            {
                var sample = BitConverter.ToInt16(args.Buffer, i * 2) / 32768f;
                _samples.Add(sample);
                var magnitude = Math.Abs(sample);
                if (magnitude > peak) peak = magnitude;
            }
        }

        // レベル更新はUI再描画コストを抑えるため間引く(macOS版 Timing と同じ考え方)。
        var now = DateTime.UtcNow;
        if (now - _lastLevelReport >= Timing.AudioLevelUpdateInterval
            && Math.Abs(peak - _lastReportedLevel) >= Timing.AudioLevelSignificantChange)
        {
            _lastLevelReport = now;
            _lastReportedLevel = peak;
            LevelChanged?.Invoke(peak);
        }
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs args)
    {
        if (args.Exception is not null && IsCapturing)
        {
            IsCapturing = false;
            CaptureFailed?.Invoke(args.Exception.Message);
        }
        var waveIn = _waveIn;
        _waveIn = null;
        waveIn?.Dispose();
    }

    public void Dispose()
    {
        Stop();
        _waveIn?.Dispose();
        _waveIn = null;
    }
}
