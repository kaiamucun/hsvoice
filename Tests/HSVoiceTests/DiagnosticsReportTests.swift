import XCTest

@testable import HSVoice

@MainActor
final class DiagnosticsReportTests: XCTestCase {
  func testReportExcludesCustomVocabulary() {
    let suiteName = "HSVoiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.dictionaryEntries = [
      DictionaryEntry(term: "CONFIDENTIAL-PRODUCT-CODENAME", spokenForms: "SECRET-SPOKEN-FORM")
    ]
    settings.replacementRules = [
      ReplacementRule(trigger: "SECRET-TRIGGER", replacement: "SECRET-ADDRESS@example.com")
    ]
    settings.aiCustomInstructions = "SECRET-INSTRUCTION"
    settings.setInsertionMode(.clipboardOnly)
    let report = DiagnosticsReport.make(
      settings: settings,
      permissions: PermissionsManager(),
      shortcutAvailable: true,
      lastError: "network unavailable",
      lastEngine: "SpeechAnalyzer"
    )

    XCTAssertFalse(report.contains("CONFIDENTIAL-PRODUCT-CODENAME"))
    XCTAssertFalse(report.contains("SECRET-SPOKEN-FORM"))
    XCTAssertFalse(report.contains("SECRET-TRIGGER"))
    XCTAssertFalse(report.contains("SECRET-ADDRESS"))
    XCTAssertFalse(report.contains("SECRET-INSTRUCTION"))
    XCTAssertTrue(report.contains("never includes dictated text"))
    XCTAssertTrue(report.contains("Last error: network unavailable"))
    XCTAssertTrue(report.contains("Insertion mode: clipboardOnly"))
    XCTAssertTrue(report.contains("Last engine used: SpeechAnalyzer"))
  }
}
