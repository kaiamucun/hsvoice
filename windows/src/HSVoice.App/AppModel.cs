using System.Windows.Threading;
using HSVoice.Core;

namespace HSVoice.App;

/// <summary>
/// 状態機械とディクテーション1回ぶんのオーケストレーション。
/// macOS版 AppModel.swift の対応物。UIスレッド上で動作し、
/// 音声・フック・推論スレッドからの通知はDispatcher経由で受け取る。
/// </summary>
public sealed class AppModel : IDisposable
{
    public const string AppVersion = "1.0.0";

    private readonly Dispatcher _dispatcher;
    public SettingsStore Settings { get; }
    public HistoryStore History { get; }
    private readonly WhisperDictationEngine _engine = new();
    private readonly AudioCapture _capture = new();
    private readonly HotKeyManager _hotKeys = new();
    private readonly TextInsertionService _insertion = new();
    private readonly SoundFeedback _sounds = new();

    private readonly DispatcherTimer _recordingTimer;
    private readonly DispatcherTimer _partialTimer;
    private DateTime _recordingStartedAt;
    private DateTime _lastPartialAt;
    private CancellationTokenSource? _dictationCancellation;
    private InsertionTarget? _target;
    private int _generation;

    private InsertionTarget? _undoTarget;
    private DateTime _undoDeadline = DateTime.MinValue;

    public VoiceState State { get; private set; } = VoiceState.Idle;

    /// <summary>オーバーレイの表示位置決定用。入力先ウィンドウのハンドル(なければ0)。</summary>
    public nint TargetWindowHandle => _target?.WindowHandle ?? 0;

    public string PartialText { get; private set; } = "";
    public string? LastText { get; private set; }
    public string? LastErrorSummary { get; private set; }
    public bool ModelMissing { get; private set; }

    public event Action? Changed;
    public event Action<double>? AudioLevelChanged;

    public bool CanUndo =>
        _undoTarget is not null && DateTime.UtcNow < _undoDeadline;

    public TimeSpan Elapsed =>
        State.Kind == VoiceStateKind.Listening ? DateTime.UtcNow - _recordingStartedAt : TimeSpan.Zero;

    public TimeSpan Remaining => RecordingLimit.MaximumDuration - Elapsed;

    public AppModel(Dispatcher dispatcher)
    {
        _dispatcher = dispatcher;
        Settings = new SettingsStore();
        History = new HistoryStore();

        _recordingTimer = new DispatcherTimer(DispatcherPriority.Normal, dispatcher)
        {
            Interval = Timing.RecordingTick,
        };
        _recordingTimer.Tick += (_, _) => OnRecordingTick();

        _partialTimer = new DispatcherTimer(DispatcherPriority.Background, dispatcher)
        {
            Interval = TimeSpan.FromMilliseconds(200),
        };
        _partialTimer.Tick += (_, _) => OnPartialTick();

        _capture.LevelChanged += level =>
            _dispatcher.BeginInvoke(() => AudioLevelChanged?.Invoke(level));
        _capture.CaptureFailed += message =>
            _dispatcher.BeginInvoke(() => FailDictation($"マイクを使用できません: {message}"));

        _hotKeys.ActivationPressed += OnActivationPressed;
        _hotKeys.ActivationReleased += OnActivationReleased;
        _hotKeys.EscapePressed += () => _dispatcher.BeginInvoke(CancelDictation);
        _sounds.Enabled = Settings.Data.SoundFeedback;
    }

    /// <summary>起動処理: フック設置とモデルの非同期読み込み。</summary>
    public void Start()
    {
        _hotKeys.Shortcut = Settings.Data.ShortcutChoice;
        _hotKeys.Install();
        _ = ReloadModelAsync();
    }

    public async Task ReloadModelAsync()
    {
        var modelPath = Settings.ResolveModelPath(AppContext.BaseDirectory);
        if (modelPath is null)
        {
            ModelMissing = true;
            NotifyChanged();
            return;
        }
        try
        {
            await _engine.EnsureLoadedAsync(modelPath);
            ModelMissing = false;
        }
        catch (Exception error)
        {
            ModelMissing = true;
            LastErrorSummary = $"モデル読み込み失敗: {error.Message}";
        }
        NotifyChanged();
    }

    public string? ModelPath => _engine.ModelPath;
    public bool ModelLoaded => _engine.IsLoaded;

    public void ApplySettingsChange()
    {
        _hotKeys.Shortcut = Settings.Data.ShortcutChoice;
        _sounds.Enabled = Settings.Data.SoundFeedback;
        NotifyChanged();
    }

    // ── ホットキー ──

    private void OnActivationPressed() => _dispatcher.BeginInvoke(() =>
    {
        if (Settings.Data.ActivationMode == ActivationMode.Hold)
        {
            StartDictation();
        }
        else
        {
            if (State.Kind == VoiceStateKind.Listening) StopDictation();
            else StartDictation();
        }
    });

    private void OnActivationReleased() => _dispatcher.BeginInvoke(() =>
    {
        if (Settings.Data.ActivationMode == ActivationMode.Hold
            && State.Kind == VoiceStateKind.Listening)
        {
            StopDictation();
        }
    });

    // ── ディクテーションのライフサイクル ──

    public void StartDictation()
    {
        if (State.IsBusy) return;
        if (ModelMissing || !_engine.IsLoaded)
        {
            // モデル未読み込みでの録音開始は、無言で失敗させず理由を見せる。
            FailDictation(ModelMissing
                ? "音声認識モデルが見つかりません(設定を確認してください)"
                : "音声認識モデルを準備中です。少し待ってからお試しください");
            return;
        }

        _generation++;
        _target = _insertion.CurrentTarget();
        _dictationCancellation = new CancellationTokenSource();
        PartialText = "";
        _recordingStartedAt = DateTime.UtcNow;
        _lastPartialAt = DateTime.MinValue;

        try
        {
            _capture.Start();
        }
        catch (Exception error)
        {
            FailDictation($"マイクを開始できません: {error.Message}");
            return;
        }

        _hotKeys.CaptureEscape = true;
        _sounds.PlayStart();
        SetState(VoiceState.Listening);
        _recordingTimer.Start();
        _partialTimer.Start();
    }

    public void StopDictation()
    {
        if (State.Kind != VoiceStateKind.Listening) return;
        StopRecordingMachinery();
        _sounds.PlayStop();
        SetState(VoiceState.Processing);
        _ = FinalizeDictationAsync(_generation);
    }

    public void CancelDictation()
    {
        if (State.Kind != VoiceStateKind.Listening) return;
        _generation++; // 進行中の最終化・パーシャルを無効化する
        StopRecordingMachinery();
        _dictationCancellation?.Cancel();
        PartialText = "";
        SetState(VoiceState.Idle);
    }

    private void StopRecordingMachinery()
    {
        _recordingTimer.Stop();
        _partialTimer.Stop();
        _capture.Stop();
        _hotKeys.CaptureEscape = false;
    }

    private void OnRecordingTick()
    {
        if (State.Kind != VoiceStateKind.Listening) return;
        if (Elapsed >= RecordingLimit.MaximumDuration)
        {
            // 55秒の安全停止(残り10秒からオーバーレイがカウントダウン表示する)。
            StopDictation();
            return;
        }
        NotifyChanged();
    }

    private void OnPartialTick()
    {
        if (State.Kind != VoiceStateKind.Listening) return;
        var now = DateTime.UtcNow;
        if (now - _lastPartialAt < Timing.PartialInferenceInterval) return;
        _lastPartialAt = now;

        var generation = _generation;
        var samples = _capture.SnapshotTail(Timing.PartialWindowMaximum);
        var locale = Settings.Data.LocaleIdentifier;
        var languageCode = LanguageCodeOf(locale);
        var prompt = WhisperDictationEngine.BuildPrompt(Settings.VocabularyTerms, languageCode);
        var cancellation = _dictationCancellation?.Token ?? CancellationToken.None;

        _ = Task.Run(async () =>
        {
            var text = await _engine.TranscribePartialAsync(
                samples, languageCode, prompt, cancellation);
            if (text is null) return;
            await _dispatcher.BeginInvoke(() =>
            {
                if (generation != _generation || State.Kind != VoiceStateKind.Listening) return;
                PartialText = text.Trim();
                NotifyChanged();
            });
        });
    }

    private async Task FinalizeDictationAsync(int generation)
    {
        string transcript;
        try
        {
            var samples = _capture.SnapshotAll();
            var locale = Settings.Data.LocaleIdentifier;
            var languageCode = LanguageCodeOf(locale);
            var prompt = WhisperDictationEngine.BuildPrompt(Settings.VocabularyTerms, languageCode);

            using var deadline = new CancellationTokenSource(Timing.FinalInferenceDeadline);
            transcript = await _engine.TranscribeAsync(
                samples, languageCode, prompt, deadline.Token);
        }
        catch (OperationCanceledException)
        {
            if (generation == _generation) FailDictation("認識が時間内に完了しませんでした");
            return;
        }
        catch (Exception error)
        {
            if (generation == _generation) FailDictation($"認識エラー: {error.Message}");
            return;
        }

        if (generation != _generation) return; // キャンセル済み

        var text = TextPostProcessor.Process(
            transcript,
            Settings.Data.LocaleIdentifier,
            Settings.Data.SpokenFormattingCommands);

        if (string.IsNullOrEmpty(text))
        {
            FailDictation("音声を認識できませんでした");
            return;
        }

        await DeliverAsync(text, _target);
    }

    private async Task DeliverAsync(string text, InsertionTarget? target)
    {
        TextInsertionOutcome outcome;
        if (Settings.Data.InsertionMode == InsertionMode.ClipboardOnly)
        {
            outcome = await _insertion.InsertAsync(text, null);
        }
        else
        {
            outcome = await _insertion.InsertAsync(text, target);
        }

        LastText = text;
        PartialText = "";

        if (Settings.Data.KeepHistory)
        {
            History.Add(HistoryEntry.Create(
                text, target?.ApplicationName, Settings.Data.LocaleIdentifier));
        }

        if (outcome == TextInsertionOutcome.Inserted)
        {
            _undoTarget = target;
            _undoDeadline = DateTime.UtcNow + RecordingLimit.UndoAvailabilityDuration;
        }
        else
        {
            _undoTarget = null;
        }

        SetState(VoiceState.Success(outcome.Message()));
        ScheduleReset(Timing.SuccessResetDelay);
    }

    /// <summary>直前のテキストをもう一度、現在の前面アプリへ入力する(トレイメニューから)。</summary>
    public Task ReinsertLastAsync() =>
        LastText is null ? Task.CompletedTask : InsertTextAsync(LastText);

    /// <summary>任意のテキスト(履歴など)を現在の前面アプリへ入力する。</summary>
    public async Task InsertTextAsync(string text)
    {
        if (State.IsBusy) return;
        var target = _insertion.CurrentTarget();
        SetState(VoiceState.Processing);
        await DeliverAsync(text, target);
    }

    public void CopyLastToClipboard()
    {
        if (LastText is null) return;
        try
        {
            System.Windows.Clipboard.SetDataObject(LastText, true);
        }
        catch { /* クリップボードのロックは無視 */ }
    }

    public void UndoLastInsertion()
    {
        if (!CanUndo) return;
        if (_insertion.Undo(_undoTarget))
        {
            _undoTarget = null;
            NotifyChanged();
        }
    }

    private void FailDictation(string message)
    {
        StopRecordingMachinery();
        LastErrorSummary = message;
        PartialText = "";
        _sounds.PlayError();
        SetState(VoiceState.Error(message));
        ScheduleReset(Timing.ErrorResetDelay);
    }

    private void ScheduleReset(TimeSpan delay)
    {
        var generation = _generation;
        _ = Task.Delay(delay).ContinueWith(_ => _dispatcher.BeginInvoke(() =>
        {
            if (generation != _generation) return;
            if (State.Kind is VoiceStateKind.Success or VoiceStateKind.Error)
            {
                SetState(VoiceState.Idle);
            }
        }));
    }

    private void SetState(VoiceState state)
    {
        State = state;
        NotifyChanged();
    }

    private void NotifyChanged() => Changed?.Invoke();

    private static string LanguageCodeOf(string localeIdentifier) =>
        localeIdentifier.Length >= 2 ? localeIdentifier[..2].ToLowerInvariant() : "auto";

    public void Dispose()
    {
        _generation++;
        StopRecordingMachinery();
        _hotKeys.Dispose();
        _capture.Dispose();
        _engine.Dispose();
        _sounds.Dispose();
    }
}
