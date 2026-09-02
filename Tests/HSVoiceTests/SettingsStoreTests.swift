import Foundation
import XCTest

@testable import HSVoice

@MainActor
final class SettingsStoreTests: XCTestCase {
  func testRepeatShortcutSettingsPersistAcrossRelaunch() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = SettingsStore(defaults: defaults)
    let combo = InputCombo.mouse(MouseButtonCombo(buttonNumber: 3, carbonModifiers: 0))
    first.repeatShortcutEnabled = true
    first.repeatShortcut = combo
    first.shortcutChoice = .custom(.key(KeyCombo(keyCode: 38, carbonModifiers: 4096)))

    let second = SettingsStore(defaults: defaults)
    XCTAssertTrue(second.repeatShortcutEnabled)
    XCTAssertEqual(second.repeatShortcut, combo)
    XCTAssertEqual(
      second.shortcutChoice, .custom(.key(KeyCombo(keyCode: 38, carbonModifiers: 4096))))
  }

  func testFreshInstallUsesReadyToSpeakDefaults() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)

    XCTAssertEqual(settings.localeIdentifier, "ja-JP")
    XCTAssertTrue(settings.preferOnDevice)
    XCTAssertFalse(settings.keepHistory)
    XCTAssertEqual(settings.activationMode, .hold)
    XCTAssertEqual(settings.insertionMode, .automatic)
    XCTAssertEqual(settings.shortcutChoice, .functionKey)
    XCTAssertFalse(settings.repeatShortcutEnabled)
    XCTAssertEqual(settings.repeatShortcut, InputCombo.defaultRepeatShortcut)
    XCTAssertTrue(settings.spokenFormattingCommands)
    XCTAssertFalse(settings.completedOnboarding)
    XCTAssertTrue(settings.soundFeedback)
    XCTAssertTrue(settings.useAnalyzerEngine)
    XCTAssertFalse(settings.aiRefinementEnabled)
    XCTAssertEqual(settings.aiRefinementMode, .cleanup)
    XCTAssertTrue(settings.showIdleIndicator)
    XCTAssertEqual(settings.appLanguage, .japanese)
    XCTAssertTrue(settings.dictionaryEntries.isEmpty)
    XCTAssertTrue(settings.replacementRules.isEmpty)
    XCTAssertNil(settings.preferredInputDeviceUID)
    XCTAssertEqual(settings.aiCustomInstructions, "")
  }

  func testDictionaryReplacementsMicrophoneAndInstructionsPersist() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.dictionaryEntries = [DictionaryEntry(term: "JOPTGames", spokenForms: "ジョプトゲームズ")]
    settings.replacementRules = [ReplacementRule(trigger: "仕事メール", replacement: "a@example.com")]
    settings.preferredInputDeviceUID = "BuiltInMicrophoneDevice"
    settings.aiCustomInstructions = "箇条書きは使わない"

    let reloaded = SettingsStore(defaults: defaults)
    XCTAssertEqual(reloaded.dictionaryEntries, settings.dictionaryEntries)
    XCTAssertEqual(reloaded.replacementRules, settings.replacementRules)
    XCTAssertEqual(reloaded.preferredInputDeviceUID, "BuiltInMicrophoneDevice")
    XCTAssertEqual(reloaded.aiCustomInstructions, "箇条書きは使わない")
    XCTAssertEqual(reloaded.vocabularyTerms, ["JOPTGames"])

    reloaded.preferredInputDeviceUID = nil
    XCTAssertNil(SettingsStore(defaults: defaults).preferredInputDeviceUID)
  }

  func testLegacyLineSeparatedVocabularyMigratesIntoDictionaryEntries() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("JOPTGames\nHunterSite, 木村凱亜\n", forKey: "customVocabulary")

    let settings = SettingsStore(defaults: defaults)
    XCTAssertEqual(settings.dictionaryEntries.map(\.term), ["JOPTGames", "HunterSite", "木村凱亜"])
    XCTAssertTrue(settings.dictionaryEntries.allSatisfy { $0.spokenForms.isEmpty })
    // Migrated once: the legacy key is gone and a reload reads the new store.
    XCTAssertNil(defaults.string(forKey: "customVocabulary"))
    XCTAssertEqual(SettingsStore(defaults: defaults).dictionaryEntries, settings.dictionaryEntries)
  }

  func testResetGeneralDefaultsRestoresShippedValues() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.activationMode = .auto
    settings.soundFeedback = false
    settings.showIdleIndicator = false
    settings.setInsertionMode(.clipboardOnly)

    settings.resetGeneralDefaults()
    XCTAssertEqual(settings.activationMode, .hold)
    XCTAssertTrue(settings.soundFeedback)
    XCTAssertTrue(settings.showIdleIndicator)
    XCTAssertEqual(settings.insertionMode, .automatic)
  }

  func testAppLanguageAndIdleIndicatorPersist() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    // Restore the global UI language even on assertion failure, so test order
    // can't leak an English UI into other tests.
    defer { settings.appLanguage = .japanese }
    settings.appLanguage = .english
    settings.showIdleIndicator = false

    let reloaded = SettingsStore(defaults: defaults)
    XCTAssertEqual(reloaded.appLanguage, .english)
    XCTAssertFalse(reloaded.showIdleIndicator)
  }

  func testAIRefinementPreferencesPersist() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.aiRefinementEnabled = true
    settings.aiRefinementMode = .summarize

    let reloaded = SettingsStore(defaults: defaults)
    XCTAssertTrue(reloaded.aiRefinementEnabled)
    XCTAssertEqual(reloaded.aiRefinementMode, .summarize)
  }

  func testAIRefinementModesHaveUniqueUserFacingLabels() {
    let labels = RefinementMode.allCases.map(\.label)
    XCTAssertEqual(labels.count, Set(labels).count)
  }

  func testSoundAndEnginePreferencesPersist() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.soundFeedback = false
    settings.useAnalyzerEngine = false

    let reloaded = SettingsStore(defaults: defaults)
    XCTAssertFalse(reloaded.soundFeedback)
    XCTAssertFalse(reloaded.useAnalyzerEngine)
  }

  func testInsertionModeDefaultsToAutomaticAndPersists() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    XCTAssertEqual(settings.insertionMode, .automatic)

    settings.setInsertionMode(.clipboardOnly)
    let reloaded = SettingsStore(defaults: defaults)
    XCTAssertEqual(reloaded.insertionMode, .clipboardOnly)
  }

  func testLegacyClipboardOnlyModeRestoresAutomaticAfterPermissionGrant() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(InsertionMode.clipboardOnly.rawValue, forKey: "insertionMode")

    let settings = SettingsStore(defaults: defaults)
    XCTAssertFalse(settings.restoreAutomaticInsertionIfPermissionGranted(false))
    XCTAssertEqual(settings.insertionMode, .clipboardOnly)

    XCTAssertTrue(settings.restoreAutomaticInsertionIfPermissionGranted(true))
    XCTAssertEqual(settings.insertionMode, .automatic)
  }

  func testPermissionFallbackRestoresButExplicitClipboardChoiceDoesNot() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.useClipboardOnlyAsPermissionFallback()
    XCTAssertTrue(settings.restoreAutomaticInsertionIfPermissionGranted(true))
    XCTAssertEqual(settings.insertionMode, .automatic)

    settings.setInsertionMode(.clipboardOnly)
    XCTAssertFalse(settings.restoreAutomaticInsertionIfPermissionGranted(true))
    XCTAssertEqual(settings.insertionMode, .clipboardOnly)
  }

  func testInsertionModesHaveUniqueUserFacingLabels() {
    let modes = InsertionMode.allCases
    XCTAssertEqual(Set(modes.map(\.label)).count, modes.count)
    XCTAssertTrue(modes.allSatisfy { !$0.detail.isEmpty })
  }
}
