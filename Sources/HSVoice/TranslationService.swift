import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

enum TranslationBackendKind: String, Sendable, Equatable {
  case appleTranslation
  case appleIntelligence
}

enum TranslationFrameworkAvailability: Equatable, Sendable {
  case installed
  case notInstalled
}

enum TranslationStatus: Equatable, Sendable {
  case translated(TranslationBackendKind)
  case unchanged(TranslationBackendKind)
  case skippedSameLanguage
  case emptyInput
  case unavailable
  case timedOut
  case cancelled
  case failed
  case inputTooLong
}

struct TranslationResult: Sendable {
  let text: String?
  let status: TranslationStatus
}

enum TranslationBackendError: Error {
  case unavailable
  case inputTooLong
}

/// On-device translation of a finished transcript. Apple Translation is the
/// default when the language pair is installed; Apple Intelligence is used
/// when that pair is missing, or when the user has translation instructions.
/// Failure never returns a partial translation. The caller owns whether to
/// insert the original transcript.
enum TranslationService {
  static let timeout: TimeInterval = 30
  static let maxTranscriptBytes = 4_000
  static let maxCustomInstructionBytes = 900

  static var isAppleTranslationSupported: Bool {
    #if canImport(Translation)
      if #available(macOS 15.0, *) { return true }
    #endif
    return false
  }

  static func frameworkAvailability(source: String, target: String) async
    -> TranslationFrameworkAvailability
  {
    #if canImport(Translation)
      if #available(macOS 15.0, *) {
        return await AppleTranslationBackend.isPairInstalled(source: source, target: target)
          ? .installed : .notInstalled
      }
    #endif
    return .notInstalled
  }

  static func translateWithResult(
    _ text: String, sourceLocale: String, targetLocale: String, vocabulary: [String] = [],
    customInstructions: String = "", applicationName: String? = nil
  ) async -> TranslationResult {
    let frameworkAvailability = await frameworkAvailability(
      source: sourceLocale, target: targetLocale)
    return await translateWithResult(
      text, sourceLocale: sourceLocale, targetLocale: targetLocale, vocabulary: vocabulary,
      customInstructions: customInstructions, applicationName: applicationName,
      frameworkAvailability: frameworkAvailability,
      intelligenceAvailability: RefinementService.availability(), timeout: timeout,
      framework: { source in
        try await translateWithAppleTranslation(
          source, sourceLocale: sourceLocale, targetLocale: targetLocale)
      },
      intelligence: { request in
        try await translateWithAppleIntelligence(request)
      }
    )
  }

  /// Injectable boundary: tests exercise routing, cancellation, and result
  /// handling without Apple Translation or Apple Intelligence on the machine.
  static func translateWithResult(
    _ text: String, sourceLocale: String, targetLocale: String, vocabulary: [String] = [],
    customInstructions: String = "", applicationName: String? = nil,
    frameworkAvailability: TranslationFrameworkAvailability,
    intelligenceAvailability: RefinementAvailability, timeout: TimeInterval = timeout,
    framework: @escaping @Sendable (String) async throws -> String,
    intelligence: @escaping @Sendable (TranslationRequest) async throws -> String
  ) async -> TranslationResult {
    guard !Task.isCancelled else { return .init(text: nil, status: .cancelled) }
    let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else { return .init(text: nil, status: .emptyInput) }
    guard !VoiceLocale.sharesLanguage(sourceLocale, targetLocale) else {
      return .init(text: nil, status: .skippedSameLanguage)
    }
    guard source.utf8.count <= maxTranscriptBytes else {
      return .init(text: nil, status: .inputTooLong)
    }

    let usableCustom = Self.usableCustomInstructions(customInstructions)
    let preferIntelligence =
      intelligenceAvailability == .available && !usableCustom.isEmpty

    if preferIntelligence {
      return await runIntelligence(
        source: source, sourceLocale: sourceLocale, targetLocale: targetLocale,
        vocabulary: vocabulary, customInstructions: usableCustom,
        applicationName: applicationName, timeout: timeout, operation: intelligence)
    }

    if frameworkAvailability == .installed {
      let frameworkResult = await run(
        source: source, backend: .appleTranslation, timeout: timeout
      ) { try await framework(source) }
      if frameworkResult.isUsable { return frameworkResult }
      if intelligenceAvailability == .available {
        let aiResult = await runIntelligence(
          source: source, sourceLocale: sourceLocale, targetLocale: targetLocale,
          vocabulary: vocabulary, customInstructions: usableCustom,
          applicationName: applicationName, timeout: timeout, operation: intelligence)
        if aiResult.isUsable { return aiResult }
      }
      return frameworkResult
    }

    if intelligenceAvailability == .available {
      return await runIntelligence(
        source: source, sourceLocale: sourceLocale, targetLocale: targetLocale,
        vocabulary: vocabulary, customInstructions: usableCustom,
        applicationName: applicationName, timeout: timeout, operation: intelligence)
    }

    return .init(text: nil, status: .unavailable)
  }

  /// Custom translation instructions that fit the model budget. Over-long
  /// text is saved in settings but not sent, matching AI polish.
  static func usableCustomInstructions(_ text: String) -> String {
    let custom = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard custom.utf8.count <= maxCustomInstructionBytes else { return "" }
    return custom
  }

  /// Drops one outer wrapping quote pair (`「…」`, `"…"`) that models often add
  /// around the whole translation. Quotes inside the sentence are kept.
  static func stripOuterWrapper(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let pairs: [(Character, Character)] = [
      ("「", "」"),
      ("『", "』"),
      ("\"", "\""),
      ("“", "”"),
      ("‘", "’"),
      ("'", "'"),
    ]
    for (open, close) in pairs {
      guard trimmed.count >= 2, trimmed.first == open, trimmed.last == close else { continue }
      let inner = String(trimmed.dropFirst().dropLast())
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if !inner.isEmpty { return inner }
    }
    return trimmed
  }

  private static func runIntelligence(
    source: String, sourceLocale: String, targetLocale: String, vocabulary: [String],
    customInstructions: String, applicationName: String?, timeout: TimeInterval,
    operation: @escaping @Sendable (TranslationRequest) async throws -> String
  ) async -> TranslationResult {
    guard
      let request = TranslationRequest.make(
        text: source, sourceLocale: sourceLocale, targetLocale: targetLocale,
        vocabulary: vocabulary, customInstructions: customInstructions,
        applicationName: applicationName)
    else { return .init(text: nil, status: .inputTooLong) }
    return await run(source: source, backend: .appleIntelligence, timeout: timeout) {
      try await operation(request)
    }
  }

  private static func run(
    source: String, backend: TranslationBackendKind, timeout: TimeInterval,
    operation: @escaping @Sendable () async throws -> String
  ) async -> TranslationResult {
    await RefinementDeadline.run(
      seconds: timeout,
      timeoutValue: TranslationResult(text: nil, status: .timedOut),
      cancellationValue: TranslationResult(text: nil, status: .cancelled)
    ) {
      do {
        let response = try await operation()
        guard !Task.isCancelled else { return .init(text: nil, status: .cancelled) }
        let translated = stripOuterWrapper(response)
        guard !translated.isEmpty else { return .init(text: nil, status: .failed) }
        return .init(
          text: translated,
          status: translated == source ? .unchanged(backend) : .translated(backend))
      } catch is CancellationError {
        return .init(text: nil, status: .cancelled)
      } catch TranslationBackendError.inputTooLong {
        return .init(text: nil, status: .inputTooLong)
      } catch {
        return .init(text: nil, status: .failed)
      }
    }
  }

  private static func translateWithAppleTranslation(
    _ text: String, sourceLocale: String, targetLocale: String
  ) async throws -> String {
    #if canImport(Translation)
      if #available(macOS 15.0, *) {
        return try await TranslationSessionCoordinator.shared.translate(
          text, sourceIdentifier: sourceLocale, targetIdentifier: targetLocale)
      }
    #endif
    throw TranslationBackendError.unavailable
  }

  private static func translateWithAppleIntelligence(_ request: TranslationRequest) async throws
    -> String
  {
    #if canImport(FoundationModels)
      if #available(macOS 26.0, *) {
        let session = LanguageModelSession(instructions: request.instructions)
        do {
          let response = try await session.respond(
            to: request.prompt, options: GenerationOptions(temperature: 0.1))
          return response.content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
          throw TranslationBackendError.inputTooLong
        }
      }
    #endif
    throw TranslationBackendError.unavailable
  }
}

extension TranslationResult {
  fileprivate var isUsable: Bool {
    switch status {
    case .translated, .unchanged: return text != nil
    default: return false
    }
  }
}
