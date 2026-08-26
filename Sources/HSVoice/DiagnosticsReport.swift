import Foundation
import Speech

enum DiagnosticsReport {
  @MainActor
  static func make(
    settings: SettingsStore,
    permissions: PermissionsManager,
    shortcutAvailable: Bool,
    lastError: String?,
    lastEngine: String? = nil
  ) -> String {
    let bundle = Bundle.main
    let version =
      bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "development"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local"
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: settings.localeIdentifier))

    let sanitizedError = lastError?
      .replacingOccurrences(of: "\n", with: " ")
      .prefix(300)
    let errorLine = sanitizedError.map(String.init) ?? "none"

    return """
      HS Voice Diagnostics
      Generated: \(ISO8601DateFormatter().string(from: Date()))
      Version: \(version) (\(build))
      macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
      Architecture: \(architectureName)
      Locale: \(settings.localeIdentifier)
      Shortcut: \(settings.shortcutChoice.displayName)
      Shortcut available: \(yesNo(shortcutAvailable))
      Activation mode: \(settings.activationMode.rawValue)
      Insertion mode: \(settings.insertionMode.rawValue)
      Prefer on-device: \(yesNo(settings.preferOnDevice))
      Analyzer engine enabled: \(yesNo(settings.useAnalyzerEngine))
      Analyzer engine supported: \(yesNo(SpeechTranscriber.analyzerEngineSupported))
      Last engine used: \(lastEngine ?? "none")
      On-device available: \(yesNo(recognizer?.supportsOnDeviceRecognition ?? false))
      Recognizer available: \(yesNo(recognizer?.isAvailable ?? false))
      Spoken formatting: \(yesNo(settings.spokenFormattingCommands))
      Microphone permission: \(yesNo(permissions.microphoneGranted))
      Speech permission: \(yesNo(permissions.speechGranted))
      Accessibility permission: \(yesNo(permissions.accessibilityGranted))
      Local history: \(yesNo(settings.keepHistory))
      Launch at login: \(yesNo(settings.launchAtLogin))
      Last error: \(errorLine)

      Privacy: This report never includes dictated text, audio, custom vocabulary, user name, or device name.
      """
  }

  private static var architectureName: String {
    #if arch(arm64)
      return "arm64"
    #elseif arch(x86_64)
      return "x86_64"
    #else
      return "unknown"
    #endif
  }

  private static func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
  }
}
