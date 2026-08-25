import XCTest

@testable import HSVoice

@MainActor
final class DiagnosticsReportTests: XCTestCase {
  func testReportExcludesCustomVocabulary() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.customVocabulary = "CONFIDENTIAL-PRODUCT-CODENAME"
    settings.setInsertionMode(.clipboardOnly)
    let report = DiagnosticsReport.make(
      settings: settings,
      permissions: PermissionsManager(),
      shortcutAvailable: true,
      lastError: "network unavailable"
    )

    XCTAssertFalse(report.contains("CONFIDENTIAL-PRODUCT-CODENAME"))
    XCTAssertTrue(report.contains("never includes dictated text"))
    XCTAssertTrue(report.contains("Last error: network unavailable"))
    XCTAssertTrue(report.contains("Insertion mode: clipboardOnly"))
  }
}
