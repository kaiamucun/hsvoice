import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// What the dictation transcript is turned into before insertion.
enum RefinementMode: String, CaseIterable, Identifiable, Codable, Sendable {
  case cleanup
  case summarize

  var id: String { rawValue }

  var label: String {
    switch self {
    case .cleanup:
      return L.t("整形（自然な文章に仕上げ）", "Polish (natural text)", "润色（自然文体）", "다듬기（자연스러운 문장）")
    case .summarize: return L.t("要約", "Summarize", "摘要", "요약")
    }
  }

  var detail: String {
    switch self {
    case .cleanup:
      return L.t(
        "フィラーや言い直しを取り除き、そのまま人に送れるきちんとした文章に仕上げます。内容は変えません。",
        "Removes fillers and self-corrections and polishes the text into something you can send as-is. The content itself is unchanged.",
        "去除口头语和改口，将文本润色为可直接发送的正式文字。内容本身不变。",
        "군말과 정정 표현을 제거하고 그대로 보낼 수 있는 정돈된 문장으로 다듬습니다. 내용은 바뀌지 않습니다.")
    case .summarize:
      return L.t(
        "話した内容を、要点だけの短い文章にまとめてから入力します。",
        "Condenses what you said into a short summary before inserting it.",
        "先将所说内容浓缩为要点摘要，再进行输入。",
        "말한 내용을 요점만 담은 짧은 문장으로 정리한 뒤 입력합니다.")
    }
  }
}

/// Why Apple Intelligence refinement can or cannot run right now.
enum RefinementAvailability: Equatable, Sendable {
  case available
  case osTooOld
  case appleIntelligenceOff
  case deviceNotSupported
  case modelNotReady
  case unavailable
}

enum RefinementStatus: Equatable, Sendable {
  case refined
  case unchanged
  case emptyInput
  case unavailable(RefinementAvailability)
  case timedOut
  case cancelled
  case failed
  case inputTooLong
}

struct RefinementResult: Sendable {
  let text: String?
  let status: RefinementStatus
}

/// On-device transcript refinement via Apple Intelligence (FoundationModels).
/// Failure never returns partially generated text. The caller owns whether to
/// insert the original transcript and how to present the outcome.
enum RefinementService {

  /// The OS ships the FoundationModels framework (macOS 26+). Says nothing
  /// about whether Apple Intelligence is enabled — see `availability()`.
  static var isSupported: Bool {
    #if canImport(FoundationModels)
      if #available(macOS 26.0, *) { return true }
    #endif
    return false
  }

  static func availability() -> RefinementAvailability {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *) else { return .osTooOld }
      let availability = SystemLanguageModel.default.availability
      if case .available = availability { return .available }
      if case .unavailable(let reason) = availability {
        switch reason {
        case .deviceNotEligible: return .deviceNotSupported
        case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
        case .modelNotReady: return .modelNotReady
        @unknown default: return .unavailable
        }
      }
      return .unavailable
    #else
      return .osTooOld
    #endif
  }

  /// Loads the model into memory ahead of the first request. Called when a
  /// recording starts so the refinement after it doesn't pay the cold-start.
  static func prewarm() {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *) else { return }
      guard case .available = SystemLanguageModel.default.availability else { return }
      Task.detached(priority: .utility) {
        LanguageModelSession().prewarm()
      }
    #endif
  }

  /// A caller-visible deadline; the model receives cancellation on expiry.
  static let timeout: TimeInterval = 30

  /// Byte limits keep Japanese, emoji, and unusually large dictionary entries
  /// bounded as well as ASCII. These are conservative preflight limits, not a
  /// tokenizer. A model context-window error is also reported as inputTooLong.
  /// We never truncate dictated text or custom instructions to make them fit.
  static let maxTranscriptBytes = 4_000
  static let maxCustomInstructionBytes = 900

  /// Compatibility wrapper for callers that only need optional refined text.
  static func refine(
    _ text: String, mode: RefinementMode, customInstructions: String = "",
    vocabulary: [String] = [], applicationName: String? = nil
  ) async -> String? {
    await refineWithResult(
      text, mode: mode, customInstructions: customInstructions,
      vocabulary: vocabulary, applicationName: applicationName
    ).text
  }

  static func refineWithResult(
    _ text: String, mode: RefinementMode, customInstructions: String = "",
    vocabulary: [String] = [], applicationName: String? = nil
  ) async -> RefinementResult {
    await refineWithResult(
      text, mode: mode, customInstructions: customInstructions,
      vocabulary: vocabulary, applicationName: applicationName,
      modelAvailability: availability(), timeout: timeout
    ) { request in
      #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
          return try await respond(to: request)
        }
      #endif
      throw RefinementBackendError.unavailable
    }
  }

  /// Injectable boundary: tests exercise actual preparation, cancellation, and
  /// result handling without requiring Apple Intelligence on the test machine.
  static func refineWithResult(
    _ text: String, mode: RefinementMode, customInstructions: String = "",
    vocabulary: [String] = [], applicationName: String? = nil,
    modelAvailability: RefinementAvailability, timeout: TimeInterval = timeout,
    operation: @escaping @Sendable (RefinementRequest) async throws -> String
  ) async -> RefinementResult {
    guard !Task.isCancelled else { return .init(text: nil, status: .cancelled) }
    let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else { return .init(text: nil, status: .emptyInput) }
    guard modelAvailability == .available else {
      return .init(text: nil, status: .unavailable(modelAvailability))
    }
    guard
      let request = RefinementRequest.make(
        text: source, mode: mode, customInstructions: customInstructions,
        vocabulary: vocabulary, applicationName: applicationName)
    else { return .init(text: nil, status: .inputTooLong) }

    return await RefinementDeadline.run(
      seconds: timeout,
      timeoutValue: RefinementResult(text: nil, status: .timedOut),
      cancellationValue: RefinementResult(text: nil, status: .cancelled)
    ) {
      do {
        let response = try await operation(request)
        guard !Task.isCancelled else { return .init(text: nil, status: .cancelled) }
        let refined = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refined.isEmpty else { return .init(text: nil, status: .failed) }
        return .init(text: refined, status: refined == source ? .unchanged : .refined)
      } catch is CancellationError {
        return .init(text: nil, status: .cancelled)
      } catch RefinementBackendError.inputTooLong {
        return .init(text: nil, status: .inputTooLong)
      } catch {
        return .init(text: nil, status: .failed)
      }
    }
  }

  #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func respond(to request: RefinementRequest) async throws -> String {
      // One fresh session and one generation per request: prior dictation must
      // never bleed into the next, and semantic editing should not add a second
      // generation round-trip. No remote API or surrounding-app content is read.
      let session = LanguageModelSession(instructions: request.instructions)
      do {
        let response = try await session.respond(
          to: request.prompt, options: GenerationOptions(temperature: 0.1))
        return response.content
      } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
        throw RefinementBackendError.inputTooLong
      }
    }
  #endif
}

enum RefinementBackendError: Error {
  case unavailable
  case inputTooLong
}
