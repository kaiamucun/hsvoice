import Foundation
import XCTest

@testable import HSVoice

@MainActor
final class SettingsStoreTests: XCTestCase {
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
    XCTAssertTrue(settings.spokenFormattingCommands)
    XCTAssertFalse(settings.completedOnboarding)
    XCTAssertTrue(settings.soundFeedback)
    XCTAssertTrue(settings.useAnalyzerEngine)
    XCTAssertFalse(settings.aiRefinementEnabled)
    XCTAssertEqual(settings.aiRefinementMode, .cleanup)
    XCTAssertTrue(settings.showIdleIndicator)
    XCTAssertEqual(settings.appLanguage, .japanese)
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
