import AVFoundation
import Accelerate
import Foundation
import Speech

enum SpeechTranscriberError: LocalizedError {
  case recognizerUnavailable
  case invalidAudioInput

  var errorDescription: String? {
    switch self {
    case .recognizerUnavailable:
      return L.t(
        "選択した言語の音声認識を現在利用できません。",
        "Speech recognition isn't currently available for the selected language.",
        "所选语言的语音识别目前不可用。",
        "선택한 언어의 음성 인식을 현재 사용할 수 없습니다.")
    case .invalidAudioInput:
      return L.t(
        "マイクの入力形式を取得できませんでした。",
        "Couldn't read the microphone's input format.",
        "无法获取麦克风的输入格式。",
        "마이크 입력 형식을 가져오지 못했습니다.")
    }
  }
}

struct SpeechSessionTracker {
  private(set) var activeID: UUID?

  mutating func begin() -> UUID {
    let id = UUID()
    activeID = id
    return id
  }

  mutating func invalidate() {
    activeID = nil
  }

  func contains(_ id: UUID) -> Bool {
    activeID == id
  }
}

/// Decides how long to keep waiting for Apple's recognizer once the audio has ended.
///
/// See ``Timing/recognitionQuietWindow`` for why finalization is driven by silence
/// rather than a fixed timeout.
struct RecognitionFinalizationPolicy {
  var settleWindow: TimeInterval = Timing.recognitionSettleWindow
  var quietWindow: TimeInterval = Timing.recognitionQuietWindow
  var emptyQuietWindow: TimeInterval = Timing.recognitionEmptyQuietWindow
  var deadline: TimeInterval = Timing.recognitionFinalizationDeadline

  /// Silence only means "finished" once the recognizer has said something since the
  /// audio ended. Before that, the app is still waiting for the first post-stop
  /// revision and has to be patient, or it would finalize on the mid-speech
  /// transcript and throw away the recognizer's best answer.
  func quietDelay(hasTranscript: Bool, sawResultSinceStop: Bool) -> TimeInterval {
    guard hasTranscript else { return emptyQuietWindow }
    return sawResultSinceStop ? quietWindow : settleWindow
  }

  /// The window is re-armed on every result, so it is clamped to what is left of the
  /// hard deadline. Without the clamp, a recognizer that keeps emitting partials
  /// forever would never finalize.
  func delayUntilFinalization(
    hasTranscript: Bool,
    sawResultSinceStop: Bool,
    elapsedSinceStop: TimeInterval
  ) -> TimeInterval {
    let remaining = max(0, deadline - elapsedSinceStop)
    return min(
      quietDelay(hasTranscript: hasTranscript, sawResultSinceStop: sawResultSinceStop),
      remaining
    )
  }
}

/// Rate-limits microphone level updates on their way into SwiftUI.
///
/// The tap runs on the real-time audio thread about 47 times a second. Every update
/// that reaches the model redraws the menu-bar popover and the floating indicator,
/// so levels are coalesced to ``Timing/audioLevelUpdateInterval`` and dropped
/// entirely when the level has barely moved — which is the whole time the user is
/// not speaking.
struct AudioLevelThrottle {
  let interval: TimeInterval
  let minimumChange: Double

  private var lastSentAt = -Double.greatestFiniteMagnitude
  private var lastLevel = -1.0

  init(
    interval: TimeInterval = Timing.audioLevelUpdateInterval,
    minimumChange: Double = Timing.audioLevelSignificantChange
  ) {
    self.interval = interval
    self.minimumChange = minimumChange
  }

  mutating func shouldSend(level: Double, at time: TimeInterval) -> Bool {
    guard time - lastSentAt >= interval else { return false }
    guard abs(level - lastLevel) >= minimumChange else { return false }
    lastSentAt = time
    lastLevel = level
    return true
  }
}

/// Thread-safe box so the audio thread can consult the throttle without touching
/// main-actor state. Shared by both dictation engines.
final class AudioLevelGate: @unchecked Sendable {
  private var throttle = AudioLevelThrottle()
  private let lock = NSLock()

  func allows(_ level: Double) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return throttle.shouldSend(level: level, at: CFAbsoluteTimeGetCurrent())
  }
}

/// Thread-safe holder for the recognition request the audio tap feeds.
///
/// Restarting the recognition task mid-recording (see the early-final handling)
/// swaps in a fresh request while the tap keeps running on the audio thread, so
/// the handoff must be lock-protected rather than a reference captured once.
final class RecognitionRequestBox: @unchecked Sendable {
  private let lock = NSLock()
  private var request: SFSpeechAudioBufferRecognitionRequest?

  func set(_ newRequest: SFSpeechAudioBufferRecognitionRequest?) {
    lock.lock()
    request = newRequest
    lock.unlock()
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    lock.lock()
    request?.append(buffer)
    lock.unlock()
  }
}

@MainActor
final class SpeechTranscriber {
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var finalizationWorkItem: DispatchWorkItem?
  private var deadlineWorkItem: DispatchWorkItem?
  private var latestText = ""

  /// Segments the recognizer finalized on its own mid-recording (it does this
  /// after a breath-length pause). They are joined with `latestText` for every
  /// partial update and for the final transcript, so a pause never loses text.
  private var bankedText = ""
  private var activeLocaleIdentifier = ""
  private var activeRecognizer: SFSpeechRecognizer?
  private var requestVocabulary: [String] = []
  private var requestOnDevice = false
  private var recognitionGeneration = 0
  private let requestBox = RecognitionRequestBox()
  private var isStopping = false
  private var didComplete = false
  private var hasAudioTap = false
  private var sessionTracker = SpeechSessionTracker()
  private var stoppedAt: Date?
  private var sawResultSinceStop = false
  private var recognizerCache: [String: SFSpeechRecognizer] = [:]
  private let finalizationPolicy = RecognitionFinalizationPolicy()

  private var onPartial: ((String) -> Void)?
  private var onLevel: ((Double) -> Void)?
  private var onCompletion: ((Result<String, Error>) -> Void)?

  var supportsOnDeviceRecognition = false

  /// Which engine produced (or is producing) the current session's text.
  enum Engine: String {
    case analyzer = "SpeechAnalyzer"
    case legacy = "SFSpeechRecognizer"
  }

  private(set) var activeEngine: Engine = .legacy
  private(set) var lastUsedEngine: Engine?

  /// Stored as `Any` because the property itself cannot carry the
  /// availability attribute; only the accessor can.
  private var analyzerEngineStorage: Any?

  @available(macOS 26.0, *)
  private var analyzerEngine: AnalyzerDictationEngine {
    if let engine = analyzerEngineStorage as? AnalyzerDictationEngine { return engine }
    let engine = AnalyzerDictationEngine()
    analyzerEngineStorage = engine
    return engine
  }

  /// True when this build of macOS offers the SpeechAnalyzer engine at all.
  nonisolated static var analyzerEngineSupported: Bool {
    if #available(macOS 26.0, *) { return true }
    return false
  }

  /// True when the high-accuracy engine can start instantly for this language.
  func analyzerEngineReady(localeIdentifier: String) -> Bool {
    if #available(macOS 26.0, *) {
      return analyzerEngine.isReady(localeIdentifier: localeIdentifier)
    }
    return false
  }

  /// Builds and caches the recognizer for a language ahead of the first recording.
  ///
  /// Creating an `SFSpeechRecognizer` opens an XPC connection to Apple's speech
  /// service. Doing that while the user is already holding the key delays the start
  /// of capture, which clips the first word. Warming it up costs nothing at idle and
  /// does not request any permission.
  @discardableResult
  func prewarm(localeIdentifier: String, includeAnalyzer: Bool = true) -> Bool {
    if includeAnalyzer, #available(macOS 26.0, *) {
      // Also resolves the analyzer's model and audio format ahead of the first
      // key press. Skipped when the user has turned the new engine off so HS
      // Voice never downloads a model that will not be used.
      analyzerEngine.prewarm(localeIdentifier: localeIdentifier)
    }
    return recognizer(for: localeIdentifier) != nil
  }

  private func recognizer(for localeIdentifier: String) -> SFSpeechRecognizer? {
    if let cached = recognizerCache[localeIdentifier] { return cached }
    guard let created = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
      return nil
    }
    recognizerCache[localeIdentifier] = created
    return created
  }

  func start(
    localeIdentifier: String,
    vocabulary: [String],
    preferOnDevice: Bool,
    useAnalyzerEngine: Bool = true,
    onPartial: @escaping (String) -> Void,
    onLevel: @escaping (Double) -> Void,
    onCompletion: @escaping (Result<String, Error>) -> Void
  ) throws {
    cancel()

    // The high-accuracy engine wins whenever it is allowed and its model is
    // ready. Vocabulary hints are a legacy-only feature (SpeechAnalyzer has no
    // contextual-string equivalent on macOS 26), which the settings UI explains.
    if useAnalyzerEngine, #available(macOS 26.0, *),
      analyzerEngine.isReady(localeIdentifier: localeIdentifier)
    {
      do {
        try analyzerEngine.start(
          localeIdentifier: localeIdentifier,
          onPartial: onPartial,
          onLevel: onLevel,
          onCompletion: onCompletion
        )
        activeEngine = .analyzer
        lastUsedEngine = .analyzer
        supportsOnDeviceRecognition = true
        return
      } catch {
        // Fall through to the legacy recognizer; a failed analyzer start
        // must never cost the user their dictation.
      }
    }
    activeEngine = .legacy
    lastUsedEngine = .legacy

    // `isAvailable` is dynamic, so it is re-checked even for a cached recognizer.
    guard let recognizer = recognizer(for: localeIdentifier), recognizer.isAvailable else {
      throw SpeechTranscriberError.recognizerUnavailable
    }

    supportsOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw SpeechTranscriberError.invalidAudioInput
    }

    self.onPartial = onPartial
    self.onLevel = onLevel
    self.onCompletion = onCompletion
    activeRecognizer = recognizer
    activeLocaleIdentifier = localeIdentifier
    requestVocabulary = vocabulary
    requestOnDevice = preferOnDevice && supportsOnDeviceRecognition
    latestText = ""
    bankedText = ""
    isStopping = false
    didComplete = false
    stoppedAt = nil
    sawResultSinceStop = false
    let sessionID = sessionTracker.begin()
    let levelGate = AudioLevelGate()
    let box = requestBox

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) {
      [weak self] buffer, _ in
      box.append(buffer)
      guard let self else { return }
      let level = AudioLevelMeter.normalizedLevel(from: buffer)
      guard levelGate.allows(level) else { return }
      Task { @MainActor in
        guard self.sessionTracker.contains(sessionID) else { return }
        self.onLevel?(level)
      }
    }
    hasAudioTap = true

    audioEngine.prepare()
    try audioEngine.start()

    startLegacyRecognitionTask(sessionID: sessionID)
  }

  /// Full transcript of the session so far: everything the recognizer already
  /// finalized plus the segment it is still revising.
  private var combinedTranscript: String {
    Self.joinSegments(bankedText, latestText, localeIdentifier: activeLocaleIdentifier)
  }

  /// Joins two finalized segments. Space-delimited languages get a space at the
  /// seam; Japanese and Chinese are joined directly.
  nonisolated static func joinSegments(
    _ first: String, _ second: String, localeIdentifier: String
  ) -> String {
    if first.isEmpty { return second }
    if second.isEmpty { return first }
    let noSpace = localeIdentifier.hasPrefix("ja") || localeIdentifier.hasPrefix("zh")
    return first + (noSpace ? "" : " ") + second
  }

  private func startLegacyRecognitionTask(sessionID: UUID) {
    guard let recognizer = activeRecognizer else { return }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    request.addsPunctuation = true
    request.contextualStrings = Array(requestVocabulary.prefix(100))
    request.requiresOnDeviceRecognition = requestOnDevice

    recognitionRequest = request
    requestBox.set(request)
    recognitionGeneration &+= 1
    let generation = recognitionGeneration

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor in
        guard let self, self.sessionTracker.contains(sessionID),
          generation == self.recognitionGeneration, !self.didComplete
        else { return }
        self.handleLegacyResult(result, error: error, sessionID: sessionID)
      }
    }
  }

  private func handleLegacyResult(
    _ result: SFSpeechRecognitionResult?, error: Error?, sessionID: UUID
  ) {
    if let result {
      latestText = result.bestTranscription.formattedString
      onPartial?(combinedTranscript)
      if result.isFinal {
        if isStopping {
          complete(.success(combinedTranscript), sessionID: sessionID)
        } else {
          // The recognizer finalizes an utterance on its own after a
          // breath-length pause. That is a segment boundary, not the end of the
          // dictation: bank the segment and immediately start a fresh task on
          // the live audio stream so nothing after the pause is lost.
          bankCurrentSegment()
          startLegacyRecognitionTask(sessionID: sessionID)
        }
        return
      }
      // The recognizer is still revising the transcript after the audio
      // ended, so restart the quiet window from this result.
      if isStopping {
        sawResultSinceStop = true
        scheduleQuietFinalization(sessionID: sessionID)
      }
    }

    if let error {
      // The generation guard already filtered callbacks from replaced tasks,
      // so this error belongs to the live task. Deliver whatever text exists
      // rather than discarding a partially successful dictation.
      if !combinedTranscript.isEmpty {
        complete(.success(combinedTranscript), sessionID: sessionID)
      } else {
        complete(.failure(error), sessionID: sessionID)
      }
    }
  }

  private func bankCurrentSegment() {
    guard !latestText.isEmpty else { return }
    bankedText = Self.joinSegments(bankedText, latestText, localeIdentifier: activeLocaleIdentifier)
    latestText = ""
  }

  func finish() {
    if activeEngine == .analyzer {
      if #available(macOS 26.0, *) {
        analyzerEngine.finish()
      }
      return
    }
    guard let sessionID = sessionTracker.activeID, !didComplete else { return }
    cancelPendingFinalization()
    isStopping = true
    stoppedAt = Date()
    sawResultSinceStop = false
    stopAudioCapture()
    recognitionRequest?.endAudio()

    let deadlineItem = DispatchWorkItem { [weak self] in
      guard let self, self.sessionTracker.contains(sessionID), !self.didComplete else { return }
      self.complete(.success(self.combinedTranscript), sessionID: sessionID)
    }
    deadlineWorkItem = deadlineItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + finalizationPolicy.deadline,
      execute: deadlineItem
    )

    scheduleQuietFinalization(sessionID: sessionID)
  }

  private func scheduleQuietFinalization(sessionID: UUID) {
    guard isStopping, !didComplete, sessionTracker.contains(sessionID) else { return }
    finalizationWorkItem?.cancel()

    let elapsed = stoppedAt.map { Date().timeIntervalSince($0) } ?? 0
    let delay = finalizationPolicy.delayUntilFinalization(
      hasTranscript: !combinedTranscript.isEmpty,
      sawResultSinceStop: sawResultSinceStop,
      elapsedSinceStop: elapsed
    )

    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.sessionTracker.contains(sessionID), !self.didComplete else { return }
      self.complete(.success(self.combinedTranscript), sessionID: sessionID)
    }
    finalizationWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  func cancel() {
    if #available(macOS 26.0, *), analyzerEngineStorage != nil {
      analyzerEngine.cancel()
    }
    activeEngine = .legacy
    sessionTracker.invalidate()
    cancelPendingFinalization()
    stopAudioCapture()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    requestBox.set(nil)
    activeRecognizer = nil
    onPartial = nil
    onLevel = nil
    onCompletion = nil
    latestText = ""
    bankedText = ""
    isStopping = false
    didComplete = false
    stoppedAt = nil
    sawResultSinceStop = false
  }

  private func cancelPendingFinalization() {
    finalizationWorkItem?.cancel()
    finalizationWorkItem = nil
    deadlineWorkItem?.cancel()
    deadlineWorkItem = nil
  }

  private func stopAudioCapture() {
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    if hasAudioTap {
      audioEngine.inputNode.removeTap(onBus: 0)
      hasAudioTap = false
    }
  }

  private func complete(_ result: Result<String, Error>, sessionID: UUID) {
    guard sessionTracker.contains(sessionID), !didComplete else { return }
    didComplete = true
    sessionTracker.invalidate()
    cancelPendingFinalization()
    stopAudioCapture()
    recognitionTask?.finish()
    let completion = onCompletion
    recognitionTask = nil
    recognitionRequest = nil
    requestBox.set(nil)
    activeRecognizer = nil
    onPartial = nil
    onLevel = nil
    onCompletion = nil
    stoppedAt = nil
    isStopping = false
    sawResultSinceStop = false
    completion?(result)
  }

}

/// RMS-based microphone level shared by both dictation engines.
enum AudioLevelMeter {
  static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
    guard let channelData = buffer.floatChannelData?.pointee else { return 0 }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return 0 }

    // One vectorized pass instead of a scalar loop over every sample, on the
    // real-time audio thread.
    var meanSquare: Float = 0
    vDSP_measqv(channelData, 1, &meanSquare, vDSP_Length(frameLength))

    let rootMeanSquare = sqrt(meanSquare)
    let decibels = 20 * log10(max(rootMeanSquare, 0.000_001))
    return Double(max(0, min(1, (decibels + 55) / 55)))
  }
}
