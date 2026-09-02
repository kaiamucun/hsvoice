import CoreGraphics
import Foundation

/// Which login session this process belongs to, and whether that session is
/// the one currently on the console.
///
/// With fast user switching, a switched-out account keeps its apps running.
/// The fn key is detected by polling `CGEventSource.keyState(.hidSystemState)`,
/// and that HID state is system-wide — so an HS Voice instance in the other
/// account sees the same press, records the same speech, and posts the same
/// text at the HID level, which lands in the active session: the dictation is
/// typed twice. Global shortcuts are therefore only live while on console.
enum UserSession {
  /// Key of `CGSessionCopyCurrentDictionary()`; the C macro
  /// `kCGSessionOnConsoleKey` is not importable into Swift.
  static let onConsoleKey = "kCGSSessionOnConsoleKey"

  static func isOnConsole() -> Bool {
    isOnConsole(sessionDictionary: CGSessionCopyCurrentDictionary() as? [String: Any])
  }

  /// A missing dictionary or key (headless host, unit tests) counts as active,
  /// so an unreadable value can never silently disable the shortcut.
  static func isOnConsole(sessionDictionary: [String: Any]?) -> Bool {
    guard let value = sessionDictionary?[onConsoleKey] else { return true }
    if let flag = value as? Bool { return flag }
    if let number = value as? NSNumber { return number.boolValue }
    return true
  }
}

/// When the two global shortcuts (dictation, re-insert) may be registered.
enum ShortcutRegistrationPolicy {
  static func shouldRegister(sessionIsActive: Bool, isCapturingShortcut: Bool) -> Bool {
    sessionIsActive && !isCapturingShortcut
  }
}
