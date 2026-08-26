import Foundation

/// The language the app's own UI is displayed in, independent of the
/// recognition (spoken) language.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
  case japanese = "ja"
  case english = "en"
  case simplifiedChinese = "zh-Hans"
  case korean = "ko"

  var id: String { rawValue }

  /// Each language is shown in itself, so every user can find their own.
  var displayName: String {
    switch self {
    case .japanese: return "日本語"
    case .english: return "English"
    case .simplifiedChinese: return "简体中文"
    case .korean: return "한국어"
    }
  }
}

/// Tiny inline localization: every user-facing string carries its four
/// translations at the call site — no string tables to drift out of sync.
///
/// `current` is kept aligned with `SettingsStore.appLanguage` (set on init and
/// on every change). Views re-render through the store's `@Published` property,
/// so a language switch repaints the UI immediately; only content that is
/// rendered once and kept (window titles of already-open windows) keeps the old
/// language until it is next created.
enum L {
  static var current: AppLanguage = .japanese

  static func t(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String {
    switch current {
    case .japanese: return ja
    case .english: return en
    case .simplifiedChinese: return zh
    case .korean: return ko
    }
  }
}
