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
