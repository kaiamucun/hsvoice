import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
  static let shared = SettingsStore()

  private enum Key {
    static let localeIdentifier = "localeIdentifier"
    static let preferOnDevice = "preferOnDevice"
    static let keepHistory = "keepHistory"
    static let activationMode = "activationMode"
    static let insertionMode = "insertionMode"
    static let insertionModeChoiceFinalized = "insertionModeChoiceFinalized"
    static let shortcutChoice = "shortcutChoice"
    static let customVocabulary = "customVocabulary"
    static let spokenFormattingCommands = "spokenFormattingCommands"
    static let completedOnboarding = "completedOnboarding"
    static let soundFeedback = "soundFeedback"
    static let useAnalyzerEngine = "useAnalyzerEngine"
  }

  private let defaults: UserDefaults

  @Published var localeIdentifier: String {
    didSet { defaults.set(localeIdentifier, forKey: Key.localeIdentifier) }
  }

  @Published var preferOnDevice: Bool {
    didSet { defaults.set(preferOnDevice, forKey: Key.preferOnDevice) }
  }

  @Published var keepHistory: Bool {
    didSet { defaults.set(keepHistory, forKey: Key.keepHistory) }
  }

  @Published var activationMode: ActivationMode {
    didSet { defaults.set(activationMode.rawValue, forKey: Key.activationMode) }
  }

  @Published private(set) var insertionMode: InsertionMode {
    didSet { defaults.set(insertionMode.rawValue, forKey: Key.insertionMode) }
  }

  @Published var shortcutChoice: ShortcutChoice {
    didSet { defaults.set(shortcutChoice.rawValue, forKey: Key.shortcutChoice) }
  }

  @Published var customVocabulary: String {
    didSet { defaults.set(customVocabulary, forKey: Key.customVocabulary) }
  }

  @Published var spokenFormattingCommands: Bool {
    didSet {
      defaults.set(spokenFormattingCommands, forKey: Key.spokenFormattingCommands)
    }
  }

  @Published var soundFeedback: Bool {
    didSet { defaults.set(soundFeedback, forKey: Key.soundFeedback) }
  }

  /// Prefer the macOS 26 SpeechAnalyzer engine when its model is ready.
  @Published var useAnalyzerEngine: Bool {
    didSet { defaults.set(useAnalyzerEngine, forKey: Key.useAnalyzerEngine) }
  }

  @Published private(set) var launchAtLogin: Bool
  @Published private(set) var launchAtLoginError: String?
  @Published var completedOnboarding: Bool {
    didSet { defaults.set(completedOnboarding, forKey: Key.completedOnboarding) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    localeIdentifier = defaults.string(forKey: Key.localeIdentifier) ?? "ja-JP"
    preferOnDevice = defaults.object(forKey: Key.preferOnDevice) as? Bool ?? true
    keepHistory = defaults.object(forKey: Key.keepHistory) as? Bool ?? false
    activationMode =
      ActivationMode(rawValue: defaults.string(forKey: Key.activationMode) ?? "") ?? .hold
    insertionMode =
      InsertionMode(rawValue: defaults.string(forKey: Key.insertionMode) ?? "") ?? .automatic
    shortcutChoice =
      ShortcutChoice(rawValue: defaults.string(forKey: Key.shortcutChoice) ?? "") ?? .functionKey
    customVocabulary = defaults.string(forKey: Key.customVocabulary) ?? ""
    spokenFormattingCommands =
      defaults.object(forKey: Key.spokenFormattingCommands) as? Bool ?? true
    completedOnboarding = defaults.bool(forKey: Key.completedOnboarding)
    soundFeedback = defaults.object(forKey: Key.soundFeedback) as? Bool ?? true
    useAnalyzerEngine = defaults.object(forKey: Key.useAnalyzerEngine) as? Bool ?? true
    launchAtLogin = SMAppService.mainApp.status == .enabled
  }

  var vocabularyTerms: [String] {
    customVocabulary
      .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",、")))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .prefix(100)
      .map { $0 }
  }

  /// Records a deliberate picker choice so a later permission refresh never overrides it.
  func setInsertionMode(_ mode: InsertionMode) {
    insertionMode = mode
    defaults.set(true, forKey: Key.insertionModeChoiceFinalized)
  }

  /// Clipboard-only selected while Accessibility was unavailable may be upgraded later.
  func useClipboardOnlyAsPermissionFallback() {
    insertionMode = .clipboardOnly
    defaults.set(false, forKey: Key.insertionModeChoiceFinalized)
  }

  /// Repairs both current permission fallbacks and legacy installs that did not store the reason.
  @discardableResult
  func restoreAutomaticInsertionIfPermissionGranted(_ granted: Bool) -> Bool {
    guard granted, insertionMode == .clipboardOnly else { return false }
    guard
      defaults.object(forKey: Key.insertionModeChoiceFinalized) == nil
        || !defaults.bool(forKey: Key.insertionModeChoiceFinalized)
    else { return false }

    insertionMode = .automatic
    defaults.set(true, forKey: Key.insertionModeChoiceFinalized)
    return true
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      launchAtLogin = enabled
      launchAtLoginError = nil
    } catch {
      launchAtLogin = SMAppService.mainApp.status == .enabled
      launchAtLoginError = error.localizedDescription
    }
  }
}
