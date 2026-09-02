import AVFoundation
import Foundation
import Speech

/// Dictation engine backed by Apple's SpeechAnalyzer stack (macOS 26+).
///
/// SpeechAnalyzer is the engine behind system dictation on macOS 26. It is
/// substantially more accurate and lower-latency than `SFSpeechRecognizer`,
/// especially for Japanese, and it always runs fully on device. The one
/// capability it does not offer (as of macOS 26) is contextual vocabulary
/// hints, so HS Voice keeps the legacy engine available for users who rely on
/// the custom dictionary — see `SpeechTranscriber.start`.
///
/// The local `SpeechTranscriber` class predates Apple's module of the same
/// name, so Apple's type is always written `Speech.SpeechTranscriber` here.
@available(macOS 26.0, *)
@MainActor
final class AnalyzerDictationEngine {

  enum EngineError: LocalizedError {
    case localeNotReady
    case invalidAudioInput

    var errorDescription: String? {
      switch self {
      case .localeNotReady:
        return L.t(
          "選択した言語の高精度認識モデルをまだ利用できません。",
          "The high-accuracy model for the selected language isn't available yet.",
          "所选语言的高精度识别模型尚不可用。",
          "선택한 언어의 고정밀 인식 모델을 아직 사용할 수 없습니다.")
      case .invalidAudioInput:
        return L.t(
          "マイクの入力形式を取得できませんでした。",
          "Couldn't read the microphone's input format.",
          "无法获取麦克风的输入格式。",
          "마이크 입력 형식을 가져오지 못했습니다.")
      }
    }
  }

  /// Locales whose on-device model is installed and whose analyzer audio
  /// format has been resolved, so `start` can run without awaiting anything.
  private(set) var readyLocaleIdentifiers: Set<String> = []
  private var preparingLocaleIdentifiers: Set<String> = []
  private var cachedFormats: [String: AVAudioFormat] = [:]

  private let audioEngine = AVAudioEngine()
  private var analyzer: SpeechAnalyzer?
  private var module: Speech.SpeechTranscriber?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?
  private var analyzerStartTask: Task<Void, Never>?
  private var finishTask: Task<Void, Never>?
  private var watchdogTask: Task<Void, Never>?
  private var hasAudioTap = false
  private var finalizedText = ""
  private var volatileText = ""
  private var isStopping = false
  private var didComplete = false
  private var sessionTracker = SpeechSessionTracker()

  private var onPartial: ((String) -> Void)?
  private var onLevel: ((Double) -> Void)?
  private var onCompletion: ((Result<String, Error>) -> Void)?

  func isReady(localeIdentifier: String) -> Bool {
    readyLocaleIdentifiers.contains(localeIdentifier)
  }

  /// Checks support, downloads the shared on-device model if missing, and
  /// resolves the analyzer's preferred audio format — all ahead of the first
  /// key press so `start` never has to await.
  func prewarm(localeIdentifier: String) {
    guard !readyLocaleIdentifiers.contains(localeIdentifier),
      !preparingLocaleIdentifiers.contains(localeIdentifier)
    else { return }
    preparingLocaleIdentifiers.insert(localeIdentifier)
    Task { [weak self] in
      await self?.prepareLocale(localeIdentifier)
    }
  }

  private func prepareLocale(_ localeIdentifier: String) async {
    defer { preparingLocaleIdentifiers.remove(localeIdentifier) }

    let locale = Locale(identifier: localeIdentifier)
    let targetTag = locale.identifier(.bcp47)

    let supported = await Speech.SpeechTranscriber.supportedLocales
    guard supported.contains(where: { $0.identifier(.bcp47) == targetTag }) else { return }

    let installed = await Speech.SpeechTranscriber.installedLocales
    if !installed.contains(where: { $0.identifier(.bcp47) == targetTag }) {
      do {
        let module = makeModule(locale: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
          try await request.downloadAndInstall()
        }
      } catch {
        // Leave the locale unready; the legacy engine keeps working and a
        // later prewarm (language switch, permission refresh) retries.
        return
      }
    }

    if cachedFormats[localeIdentifier] == nil {
      let module = makeModule(locale: locale)
      cachedFormats[localeIdentifier] =
        await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
    }
    guard cachedFormats[localeIdentifier] != nil else { return }
    readyLocaleIdentifiers.insert(localeIdentifier)
  }

  private func makeModule(locale: Locale) -> Speech.SpeechTranscriber {
    Speech.SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults],
      attributeOptions: []
    )
  }

  func start(
    localeIdentifier: String,
    inputDeviceUID: String? = nil,
    onPartial: @escaping (String) -> Void,
    onLevel: @escaping (Double) -> Void,
    onCompletion: @escaping (Result<String, Error>) -> Void
  ) throws {
    cancel()

    guard isReady(localeIdentifier: localeIdentifier),
      let analyzerFormat = cachedFormats[localeIdentifier]
    else {
      throw EngineError.localeNotReady
    }

    let module = makeModule(locale: Locale(identifier: localeIdentifier))
    let analyzer = SpeechAnalyzer(modules: [module])

    AudioInputDevices.apply(preferredUID: inputDeviceUID, to: audioEngine)
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
      throw EngineError.invalidAudioInput
    }

    self.module = module
    self.analyzer = analyzer
    self.onPartial = onPartial
    self.onLevel = onLevel
    self.onCompletion = onCompletion
    finalizedText = ""
    volatileText = ""
    isStopping = false
    didComplete = false
    let sessionID = sessionTracker.begin()

    let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    inputContinuation = continuation

    let levelGate = AudioLevelGate()
    let discardGate = InitialAudioDiscardGate(sampleRate: inputFormat.sampleRate)
    let feed = AnalyzerAudioFeed(inputFormat: inputFormat, targetFormat: analyzerFormat)

    // The tap runs on the audio thread: it only touches thread-safe locals
    // (the discard gate, the feed, the stream continuation, the level gate)
    // and hops to the main actor for UI level updates, mirroring the legacy
    // engine. The discard gate keeps the shortcut click and the start cue out
    // of the analyzer; the level meter still sees every buffer.
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
      [weak self] buffer, _ in
      if !discardGate.shouldDiscard(buffer), let converted = feed.convert(buffer) {
        continuation.yield(AnalyzerInput(buffer: converted))
      }
      guard let self else { return }
      guard let level = levelGate.smoothedLevel(AudioLevelMeter.normalizedLevel(from: buffer))
      else { return }
      Task { @MainActor in
        guard self.sessionTracker.contains(sessionID) else { return }
        self.onLevel?(level)
      }
    }
    hasAudioTap = true

    audioEngine.prepare()
    do {
      try audioEngine.start()
    } catch {
      stopAudioCapture()
      inputContinuation?.finish()
      inputContinuation = nil
      throw error
    }

    analyzerStartTask = Task { [weak self] in
      do {
        try await analyzer.start(inputSequence: inputSequence)
      } catch {
        guard let self, self.sessionTracker.contains(sessionID) else { return }
        self.complete(.failure(error), sessionID: sessionID)
      }
    }

    resultsTask = Task { [weak self] in
      do {
        for try await result in module.results {
          guard let self, self.sessionTracker.contains(sessionID), !self.didComplete else {
            return
          }
          let text = String(result.text.characters)
          if result.isFinal {
            self.finalizedText += text
            self.volatileText = ""
          } else {
            self.volatileText = text
          }
          self.onPartial?(self.currentTranscript)
        }
        guard let self, self.sessionTracker.contains(sessionID) else { return }
        self.complete(.success(self.currentTranscript), sessionID: sessionID)
      } catch {
        guard let self, self.sessionTracker.contains(sessionID) else { return }
        if self.isStopping || !self.currentTranscript.isEmpty {
          self.complete(.success(self.currentTranscript), sessionID: sessionID)
        } else {
          self.complete(.failure(error), sessionID: sessionID)
        }
      }
    }
  }

  private var currentTranscript: String {
    finalizedText + volatileText
  }

  func finish() {
    guard let analyzer, let sessionID = sessionTracker.activeID, !didComplete else { return }
    isStopping = true
    stopAudioCapture()
    inputContinuation?.finish()

    finishTask = Task { [weak self] in
      do {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        // The results stream ends next, which delivers the completion.
      } catch {
        guard let self, self.sessionTracker.contains(sessionID) else { return }
        self.complete(.success(self.currentTranscript), sessionID: sessionID)
      }
    }

    // The analyzer finalizes promptly, but a stalled session must never hold
    // the transcript hostage — same principle as the legacy deadline.
    watchdogTask = Task { [weak self] in
      let deadline = UInt64(Timing.analyzerFinalizationDeadline * 1_000_000_000)
      try? await Task.sleep(nanoseconds: deadline)
      guard let self, self.sessionTracker.contains(sessionID), !self.didComplete else { return }
      await analyzer.cancelAndFinishNow()
      guard self.sessionTracker.contains(sessionID), !self.didComplete else { return }
      self.complete(.success(self.currentTranscript), sessionID: sessionID)
    }
  }

  func cancel() {
    let activeAnalyzer = analyzer
    sessionTracker.invalidate()
    resultsTask?.cancel()
    resultsTask = nil
    analyzerStartTask = nil
    finishTask = nil
    watchdogTask?.cancel()
    watchdogTask = nil
    stopAudioCapture()
    inputContinuation?.finish()
    inputContinuation = nil
    if let activeAnalyzer {
      Task { await activeAnalyzer.cancelAndFinishNow() }
    }
    analyzer = nil
    module = nil
    onPartial = nil
    onLevel = nil
    onCompletion = nil
    finalizedText = ""
    volatileText = ""
    isStopping = false
    didComplete = false
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
    watchdogTask?.cancel()
    watchdogTask = nil
    stopAudioCapture()
    inputContinuation?.finish()
    inputContinuation = nil
    let completion = onCompletion
    analyzer = nil
    module = nil
    onPartial = nil
    onLevel = nil
    onCompletion = nil
    isStopping = false
    completion?(result)
  }
}

/// Converts microphone buffers to the analyzer's preferred format on the
/// audio thread. The input node's format almost never matches
/// `SpeechAnalyzer.bestAvailableAudioFormat`, and yielding unconverted buffers
/// fails silently — the analyzer just never produces text.
private final class AnalyzerAudioFeed: @unchecked Sendable {
  private let converter: AVAudioConverter?
  private let targetFormat: AVAudioFormat

  init(inputFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
    self.targetFormat = targetFormat
    converter =
      inputFormat == targetFormat ? nil : AVAudioConverter(from: inputFormat, to: targetFormat)
  }

  func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let converter else { return buffer }
    guard buffer.frameLength > 0 else { return nil }

    let ratio = targetFormat.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
    guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
      return nil
    }

    var consumed = false
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
      if consumed {
        inputStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      inputStatus.pointee = .haveData
      return buffer
    }

    guard status != .error, conversionError == nil, output.frameLength > 0 else { return nil }
    return output
  }
}
