import AVFoundation
import Foundation
import Speech

enum SpeechTranscriberError: LocalizedError {
  case recognizerUnavailable
  case invalidAudioInput

  var errorDescription: String? {
    switch self {
    case .recognizerUnavailable:
      return "選択した言語の音声認識を現在利用できません。"
    case .invalidAudioInput:
      return "マイクの入力形式を取得できませんでした。"
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

@MainActor
final class SpeechTranscriber {
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var finalizationWorkItem: DispatchWorkItem?
  private var latestText = ""
  private var isStopping = false
  private var didComplete = false
  private var hasAudioTap = false
  private var sessionTracker = SpeechSessionTracker()

  private var onPartial: ((String) -> Void)?
  private var onLevel: ((Double) -> Void)?
  private var onCompletion: ((Result<String, Error>) -> Void)?

  var supportsOnDeviceRecognition = false

  func start(
    localeIdentifier: String,
    vocabulary: [String],
    preferOnDevice: Bool,
    onPartial: @escaping (String) -> Void,
    onLevel: @escaping (Double) -> Void,
    onCompletion: @escaping (Result<String, Error>) -> Void
  ) throws {
    cancel()

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
      recognizer.isAvailable
    else {
      throw SpeechTranscriberError.recognizerUnavailable
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    request.addsPunctuation = true
    request.contextualStrings = Array(vocabulary.prefix(100))
    supportsOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    request.requiresOnDeviceRecognition = preferOnDevice && supportsOnDeviceRecognition

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw SpeechTranscriberError.invalidAudioInput
    }

    self.onPartial = onPartial
    self.onLevel = onLevel
    self.onCompletion = onCompletion
    recognitionRequest = request
    latestText = ""
    isStopping = false
    didComplete = false
    let sessionID = sessionTracker.begin()

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) {
      [weak self, weak request] buffer, _ in
      request?.append(buffer)
      guard let self else { return }
      let level = Self.normalizedLevel(from: buffer)
      Task { @MainActor in
        guard self.sessionTracker.contains(sessionID) else { return }
        self.onLevel?(level)
      }
    }
    hasAudioTap = true

    audioEngine.prepare()
    try audioEngine.start()

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor in
        guard let self, self.sessionTracker.contains(sessionID), !self.didComplete else { return }

        if let result {
          self.latestText = result.bestTranscription.formattedString
          self.onPartial?(self.latestText)
          if result.isFinal {
            self.complete(.success(self.latestText), sessionID: sessionID)
            return
          }
        }

        if let error {
          if self.isStopping, !self.latestText.isEmpty {
            self.complete(.success(self.latestText), sessionID: sessionID)
          } else {
            self.complete(.failure(error), sessionID: sessionID)
          }
        }
      }
    }
  }

  func finish() {
    guard let sessionID = sessionTracker.activeID, !didComplete else { return }
    isStopping = true
    stopAudioCapture()
    recognitionRequest?.endAudio()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.sessionTracker.contains(sessionID), !self.didComplete else { return }
      self.complete(.success(self.latestText), sessionID: sessionID)
    }
    finalizationWorkItem = workItem
    let fallbackDelay = latestText.isEmpty ? 1.8 : 1.1
    DispatchQueue.main.asyncAfter(deadline: .now() + fallbackDelay, execute: workItem)
  }

  func cancel() {
    sessionTracker.invalidate()
    finalizationWorkItem?.cancel()
    finalizationWorkItem = nil
    stopAudioCapture()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    onPartial = nil
    onLevel = nil
    onCompletion = nil
    latestText = ""
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
    finalizationWorkItem?.cancel()
    stopAudioCapture()
    recognitionTask?.finish()
    let completion = onCompletion
    recognitionTask = nil
    recognitionRequest = nil
    onPartial = nil
    onLevel = nil
    onCompletion = nil
    completion?(result)
  }

  nonisolated private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
    guard let channelData = buffer.floatChannelData?.pointee else { return 0 }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return 0 }

    var sum: Float = 0
    for index in 0..<frameLength {
      let sample = channelData[index]
      sum += sample * sample
    }
    let rootMeanSquare = sqrt(sum / Float(frameLength))
    let decibels = 20 * log10(max(rootMeanSquare, 0.000_001))
    return Double(max(0, min(1, (decibels + 55) / 55)))
  }
}
