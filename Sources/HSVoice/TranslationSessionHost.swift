import SwiftUI

#if canImport(Translation)
  import Translation
#endif

/// Bridges Apple's SwiftUI-only `TranslationSession` into `TranslationService`.
/// The overlay stays in the view hierarchy, so the session is valid whenever
/// a recording finishes.
struct TranslationSessionHostModifier: ViewModifier {
  func body(content: Content) -> some View {
    #if canImport(Translation)
      if #available(macOS 15.0, *) {
        content.modifier(ActiveTranslationSessionHost())
      } else {
        content
      }
    #else
      content
    #endif
  }
}

extension View {
  func appleTranslationSessionHost() -> some View {
    modifier(TranslationSessionHostModifier())
  }
}

#if canImport(Translation)
  @available(macOS 15.0, *)
  private struct ActiveTranslationSessionHost: ViewModifier {
    @ObservedObject private var coordinator = TranslationSessionCoordinator.shared

    func body(content: Content) -> some View {
      content.translationTask(coordinator.configuration) { session in
        await coordinator.handle(session)
      }
    }
  }

  @available(macOS 15.0, *)
  enum AppleTranslationBackend {
    static func isPairInstalled(source: String, target: String) async -> Bool {
      let availability = LanguageAvailability()
      let status = await availability.status(
        from: Locale(identifier: source).language,
        to: Locale(identifier: target).language
      )
      if case .installed = status { return true }
      return false
    }
  }

  @available(macOS 15.0, *)
  @MainActor
  final class TranslationSessionCoordinator: ObservableObject {
    static let shared = TranslationSessionCoordinator()

    @Published var configuration: TranslationSession.Configuration?

    private var pendingText: String?
    private var pendingContinuation: CheckedContinuation<String, Error>?
    private var lastSourceIdentifier: String?
    private var lastTargetIdentifier: String?

    func translate(
      _ text: String, sourceIdentifier: String, targetIdentifier: String
    ) async throws -> String {
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          finishPending(with: CancellationError())
          pendingText = text
          pendingContinuation = continuation
          let source = Locale(identifier: sourceIdentifier).language
          let target = Locale(identifier: targetIdentifier).language
          if var current = configuration,
            lastSourceIdentifier == sourceIdentifier,
            lastTargetIdentifier == targetIdentifier
          {
            current.invalidate()
            configuration = current
          } else {
            lastSourceIdentifier = sourceIdentifier
            lastTargetIdentifier = targetIdentifier
            configuration = TranslationSession.Configuration(source: source, target: target)
          }
        }
      } onCancel: {
        Task { @MainActor in
          TranslationSessionCoordinator.shared.finishPending(with: CancellationError())
        }
      }
    }

    func handle(_ session: TranslationSession) async {
      guard let text = pendingText, let continuation = pendingContinuation else { return }
      pendingText = nil
      pendingContinuation = nil
      do {
        let response = try await session.translate(text)
        continuation.resume(returning: response.targetText)
      } catch {
        continuation.resume(throwing: error)
      }
    }

    private func finishPending(with error: Error) {
      pendingText = nil
      guard let continuation = pendingContinuation else { return }
      pendingContinuation = nil
      continuation.resume(throwing: error)
    }
  }
#endif
