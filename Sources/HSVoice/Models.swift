import AppKit
import Foundation

enum VoiceState: Equatable {
  case idle
  case requestingPermission
  case listening
  case processing
  case success(String)
  case error(String)

  var isBusy: Bool {
    switch self {
    case .requestingPermission, .listening, .processing:
      return true
    default:
      return false
    }
  }

  var isError: Bool {
    if case .error = self { return true }
    return false
  }

  var allowsConfigurationChanges: Bool {
    !isBusy
  }

  var overlayPresentation: VoiceOverlayPresentation {
    self == .idle ? .compact : .expanded
  }

  var title: String {
    switch self {
    case .idle:
      return "待機中"
    case .requestingPermission:
      return "権限を確認中"
    case .listening:
      return "聞いています"
    case .processing:
      return "仕上げています"
    case .success:
      return "入力しました"
    case .error:
      return "確認が必要です"
    }
  }

  var symbolName: String {
    switch self {
    case .idle:
      return "waveform"
    case .requestingPermission:
      return "lock.shield"
    case .listening:
      return "waveform.circle.fill"
    case .processing:
      return "sparkles"
    case .success:
      return "checkmark.circle.fill"
    case .error:
      return "exclamationmark.triangle.fill"
    }
  }
}

enum VoiceOverlayPresentation: Equatable {
  case compact
  case expanded
}

enum ActivationMode: String, CaseIterable, Identifiable, Codable {
  case hold
  case toggle

  var id: String { rawValue }

  var label: String {
    switch self {
    case .hold: return "押している間"
    case .toggle: return "押すたびに開始・停止"
    }
  }
}

enum InsertionMode: String, CaseIterable, Identifiable, Codable {
  case automatic
  case clipboardOnly

  var id: String { rawValue }

  var label: String {
    switch self {
    case .automatic: return "カーソル位置へ自動入力"
    case .clipboardOnly: return "クリップボードへコピーのみ"
    }
  }

  var shortLabel: String {
    switch self {
    case .automatic: return "自動入力"
    case .clipboardOnly: return "コピーのみ"
    }
  }

  var symbolName: String {
    switch self {
    case .automatic: return "text.cursor"
    case .clipboardOnly: return "doc.on.clipboard"
    }
  }

  var detail: String {
    switch self {
    case .automatic:
      return "録音前に使っていたアプリのカーソル位置へ直接入力します。クリップボードは使いません。アクセシビリティ権限が必要です。"
    case .clipboardOnly:
      return "自動入力を行わず、認識結果をクリップボードへ残します。"
    }
  }
}

enum ShortcutChoice: String, CaseIterable, Identifiable, Codable {
  case functionKey
  case optionSpace
  case controlSpace
  case commandShiftSpace
  case controlOptionSpace

  var id: String { rawValue }

  var keyLabels: [String] {
    switch self {
    case .functionKey: return ["fn"]
    case .optionSpace: return ["⌥", "Space"]
    case .controlSpace: return ["⌃", "Space"]
    case .commandShiftSpace: return ["⌘", "⇧", "Space"]
    case .controlOptionSpace: return ["⌃", "⌥", "Space"]
    }
  }

  var displayName: String {
    keyLabels.joined(separator: " ")
  }
}

struct VoiceLocale: Identifiable, Hashable {
  let identifier: String
  let displayName: String
  let nativeName: String

  var id: String { identifier }

  static let recommended: [VoiceLocale] = [
    .init(identifier: "ja-JP", displayName: "Japanese", nativeName: "日本語"),
    .init(identifier: "en-US", displayName: "English (US)", nativeName: "English (US)"),
    .init(identifier: "en-GB", displayName: "English (UK)", nativeName: "English (UK)"),
    .init(identifier: "zh-CN", displayName: "Chinese (Simplified)", nativeName: "简体中文"),
    .init(identifier: "zh-TW", displayName: "Chinese (Traditional)", nativeName: "繁體中文"),
    .init(identifier: "ko-KR", displayName: "Korean", nativeName: "한국어"),
    .init(identifier: "fr-FR", displayName: "French", nativeName: "Français"),
    .init(identifier: "de-DE", displayName: "German", nativeName: "Deutsch"),
    .init(identifier: "es-ES", displayName: "Spanish", nativeName: "Español"),
    .init(identifier: "it-IT", displayName: "Italian", nativeName: "Italiano"),
    .init(
      identifier: "pt-BR", displayName: "Portuguese (Brazil)", nativeName: "Português (Brasil)"),
  ]
}

struct HistoryEntry: Identifiable, Codable, Equatable {
  let id: UUID
  let createdAt: Date
  let text: String
  let applicationName: String?
  let localeIdentifier: String

  init(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    text: String,
    applicationName: String?,
    localeIdentifier: String
  ) {
    self.id = id
    self.createdAt = createdAt
    self.text = text
    self.applicationName = applicationName
    self.localeIdentifier = localeIdentifier
  }
}

enum TextInsertionOutcome: Equatable {
  case inserted
  case copiedOnly
  case copiedNoAccessibility

  var message: String {
    switch self {
    case .inserted:
      return "カーソル位置に入力しました"
    case .copiedOnly:
      return "クリップボードにコピーしました"
    case .copiedNoAccessibility:
      return "アクセシビリティ権限が無効のためコピーしました"
    }
  }
}

enum RecordingLimit {
  static let maximumDuration: TimeInterval = 55
  static let undoAvailabilityDuration: TimeInterval = 8

  /// Once this little time remains, the overlay switches from the elapsed time
  /// to an orange countdown so the 55-second safety stop never surprises.
  static let countdownWarningRemaining: TimeInterval = 10
}

struct AppTarget {
  let application: NSRunningApplication

  var processIdentifier: pid_t {
    application.processIdentifier
  }

  var displayName: String {
    application.localizedName ?? "前のアプリ"
  }
}
