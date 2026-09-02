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
    static let repeatShortcutEnabled = "repeatShortcutEnabled"
    static let repeatShortcut = "repeatShortcut"
    static let customVocabulary = "customVocabulary"
    static let spokenFormattingCommands = "spokenFormattingCommands"
    static let completedOnboarding = "completedOnboarding"
    static let soundFeedback = "soundFeedback"
    static let useAnalyzerEngine = "useAnalyzerEngine"
    static let appLanguage = "appLanguage"
    static let showIdleIndicator = "showIdleIndicator"
    static let aiRefinementEnabled = "aiRefinementEnabled"
    static let aiRefinementMode = "aiRefinementMode"
    static let aiCustomInstructions = "aiCustomInstructions"
    static let dictionaryEntries = "dictionaryEntries"
    static let replacementRules = "replacementRules"
    static let preferredInputDeviceUID = "preferredInputDeviceUID"
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

  /// Whether the global "re-insert the last dictation" shortcut is active.
  @Published var repeatShortcutEnabled: Bool {
    didSet { defaults.set(repeatShortcutEnabled, forKey: Key.repeatShortcutEnabled) }
  }

  /// The key or mouse-button combination that re-inserts the last dictation.
  @Published var repeatShortcut: InputCombo {
    didSet { defaults.set(repeatShortcut.storageString, forKey: Key.repeatShortcut) }
  }

  /// Names and terms with their misrecognized forms — see `TextReplacer`.
  @Published var dictionaryEntries: [DictionaryEntry] {
    didSet { store(dictionaryEntries, forKey: Key.dictionaryEntries) }
  }

  /// Spoken trigger phrases expanded into longer text — see `TextReplacer`.
  @Published var replacementRules: [ReplacementRule] {
    didSet { store(replacementRules, forKey: Key.replacementRules) }
  }

  /// CoreAudio device UID of the microphone to record from; nil = system default.
  @Published var preferredInputDeviceUID: String? {
    didSet {
      if let preferredInputDeviceUID {
        defaults.set(preferredInputDeviceUID, forKey: Key.preferredInputDeviceUID)
      } else {
        defaults.removeObject(forKey: Key.preferredInputDeviceUID)
      }
    }
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

  /// The language the app's UI is displayed in. Mirrored into `L.current`
  /// so plain string lookups anywhere in the app follow the setting.
  @Published var appLanguage: AppLanguage {
    didSet {
      defaults.set(appLanguage.rawValue, forKey: Key.appLanguage)
      L.current = appLanguage
    }
  }

  /// Keep the tiny idle pill visible at the bottom of the screen.
  @Published var showIdleIndicator: Bool {
    didSet { defaults.set(showIdleIndicator, forKey: Key.showIdleIndicator) }
  }

  /// Run the transcript through Apple Intelligence before inserting it.
  @Published var aiRefinementEnabled: Bool {
    didSet { defaults.set(aiRefinementEnabled, forKey: Key.aiRefinementEnabled) }
  }

  @Published var aiRefinementMode: RefinementMode {
    didSet { defaults.set(aiRefinementMode.rawValue, forKey: Key.aiRefinementMode) }
  }

  /// Free-form style rules appended to the Apple Intelligence instructions.
  @Published var aiCustomInstructions: String {
    didSet { defaults.set(aiCustomInstructions, forKey: Key.aiCustomInstructions) }
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
    repeatShortcutEnabled = defaults.object(forKey: Key.repeatShortcutEnabled) as? Bool ?? false
    repeatShortcut =
      InputCombo(storageString: defaults.string(forKey: Key.repeatShortcut) ?? "")
      ?? .defaultRepeatShortcut
    // The 1.6 dictionary was one term per line; it becomes entries without
    // spoken forms, so nothing the user typed is lost by the upgrade.
    let migratedDictionary: [DictionaryEntry]?
    if let stored: [DictionaryEntry] = Self.decode(from: defaults, key: Key.dictionaryEntries) {
      dictionaryEntries = stored
      migratedDictionary = nil
    } else {
      let legacy = Self.legacyVocabularyTerms(defaults.string(forKey: Key.customVocabulary) ?? "")
      let entries = legacy.map { DictionaryEntry(term: $0) }
      dictionaryEntries = entries
      migratedDictionary = entries.isEmpty ? nil : entries
    }
    replacementRules = Self.decode(from: defaults, key: Key.replacementRules) ?? []
    preferredInputDeviceUID = defaults.string(forKey: Key.preferredInputDeviceUID)
    aiCustomInstructions = defaults.string(forKey: Key.aiCustomInstructions) ?? ""
    spokenFormattingCommands =
      defaults.object(forKey: Key.spokenFormattingCommands) as? Bool ?? true
    completedOnboarding = defaults.bool(forKey: Key.completedOnboarding)
    soundFeedback = defaults.object(forKey: Key.soundFeedback) as? Bool ?? true
    useAnalyzerEngine = defaults.object(forKey: Key.useAnalyzerEngine) as? Bool ?? true
    appLanguage =
      AppLanguage(rawValue: defaults.string(forKey: Key.appLanguage) ?? "") ?? .japanese
    showIdleIndicator = defaults.object(forKey: Key.showIdleIndicator) as? Bool ?? true
    aiRefinementEnabled = defaults.object(forKey: Key.aiRefinementEnabled) as? Bool ?? false
    aiRefinementMode =
      RefinementMode(rawValue: defaults.string(forKey: Key.aiRefinementMode) ?? "") ?? .cleanup
    launchAtLogin = SMAppService.mainApp.status == .enabled
    L.current = appLanguage
    if let migratedDictionary {
      store(migratedDictionary, forKey: Key.dictionaryEntries)
      defaults.removeObject(forKey: Key.customVocabulary)
    }
  }

  /// Dictionary terms as recognition hints for the classic engine (which caps
  /// contextual strings at 100) and as spelling hints for AI refinement.
  var vocabularyTerms: [String] {
    dictionaryEntries
      .map(\.trimmedTerm)
      .filter { !$0.isEmpty }
      .prefix(100)
      .map { $0 }
  }

  /// The corrections to run on every transcript of the next recording.
  func makeReplacer() -> TextReplacer {
    TextReplacer(dictionary: dictionaryEntries, replacements: replacementRules)
  }

  func addDictionaryEntry() -> DictionaryEntry? {
    guard dictionaryEntries.count < TextReplacer.dictionaryLimit else { return nil }
    let entry = DictionaryEntry(term: "")
    dictionaryEntries.append(entry)
    return entry
  }

  func removeDictionaryEntry(id: UUID) {
    dictionaryEntries.removeAll { $0.id == id }
  }

  @discardableResult
  func addReplacementRule(trigger: String = "", replacement: String = "") -> ReplacementRule? {
    guard replacementRules.count < TextReplacer.replacementLimit else { return nil }
    let rule = ReplacementRule(trigger: trigger, replacement: replacement)
    replacementRules.append(rule)
    return rule
  }

  func removeReplacementRule(id: UUID) {
    replacementRules.removeAll { $0.id == id }
  }

  /// "Reset to defaults" for the General page.
  func resetGeneralDefaults() {
    activationMode = .hold
    soundFeedback = true
    showIdleIndicator = true
    setInsertionMode(.automatic)
  }

  private static func legacyVocabularyTerms(_ text: String) -> [String] {
    text
      .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",、")))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func decode<T: Decodable>(from defaults: UserDefaults, key: String) -> T? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  private func store<T: Encodable>(_ value: T, forKey key: String) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    defaults.set(data, forKey: key)
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
