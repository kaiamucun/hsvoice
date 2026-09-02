import XCTest

@testable import HSVoice

/// A switched-out login session (fast user switching) still sees the global
/// fn HID state, so an HS Voice instance there would record and type in
/// parallel with the active session's instance — the "text inserted twice"
/// bug. Shortcuts may only be live while this session is on the console.
final class UserSessionTests: XCTestCase {
  func testShortcutsAreLiveOnlyWhileOnConsoleAndNotCapturing() {
    XCTAssertTrue(
      ShortcutRegistrationPolicy.shouldRegister(sessionIsActive: true, isCapturingShortcut: false))
    XCTAssertFalse(
      ShortcutRegistrationPolicy.shouldRegister(sessionIsActive: false, isCapturingShortcut: false))
    XCTAssertFalse(
      ShortcutRegistrationPolicy.shouldRegister(sessionIsActive: true, isCapturingShortcut: true))
    XCTAssertFalse(
      ShortcutRegistrationPolicy.shouldRegister(sessionIsActive: false, isCapturingShortcut: true))
  }

  func testConsoleFlagIsReadFromSessionDictionary() {
    XCTAssertTrue(UserSession.isOnConsole(sessionDictionary: ["kCGSSessionOnConsoleKey": true]))
    XCTAssertFalse(UserSession.isOnConsole(sessionDictionary: ["kCGSSessionOnConsoleKey": false]))
    // No session dictionary at all (headless / unit test host): assume active so
    // a missing value can never silently disable the shortcut.
    XCTAssertTrue(UserSession.isOnConsole(sessionDictionary: nil))
    XCTAssertTrue(UserSession.isOnConsole(sessionDictionary: [:]))
  }
}
