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
      return L.t("待機中", "Ready", "待机中", "대기 중")
    case .requestingPermission:
      return L.t("権限を確認中", "Checking permissions", "正在检查权限", "권한 확인 중")
    case .listening:
      return L.t("聞いています", "Listening", "正在聆听", "듣고 있습니다")
    case .processing:
      return L.t("仕上げています", "Finishing up", "正在整理", "마무리 중")
    case .success:
      return L.t("入力しました", "Done", "已输入", "입력했습니다")
    case .error:
      return L.t("確認が必要です", "Needs attention", "需要确认", "확인이 필요합니다")
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
    case .hold: return L.t("押している間", "While held down", "按住期间", "누르고 있는 동안")
    case .toggle:
      return L.t("押すたびに開始・停止", "Press to start / stop", "按一次开始，再按停止", "누를 때마다 시작·정지")
    }
  }
}

enum InsertionMode: String, CaseIterable, Identifiable, Codable {
  case automatic
  case clipboardOnly

  var id: String { rawValue }

  var label: String {
    switch self {
    case .automatic:
      return L.t("カーソル位置へ自動入力", "Type at the cursor automatically", "自动输入到光标位置", "커서 위치에 자동 입력")
    case .clipboardOnly:
      return L.t("クリップボードへコピーのみ", "Copy to clipboard only", "仅复制到剪贴板", "클립보드에 복사만")
    }
  }

  var shortLabel: String {
    switch self {
    case .automatic: return L.t("自動入力", "Auto-type", "自动输入", "자동 입력")
    case .clipboardOnly: return L.t("コピーのみ", "Copy only", "仅复制", "복사만")
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
      return L.t(
        "録音前に使っていたアプリのカーソル位置へ直接入力します。クリップボードは使いません。アクセシビリティ権限が必要です。",
        "Types directly at the cursor in the app you were using before recording. The clipboard is not used. Requires the Accessibility permission.",
        "直接输入到录音前所用应用的光标位置。不使用剪贴板。需要辅助功能权限。",
        "녹음 전에 사용하던 앱의 커서 위치에 직접 입력합니다. 클립보드는 사용하지 않습니다. 손쉬운 사용 권한이 필요합니다.")
    case .clipboardOnly:
      return L.t(
        "自動入力を行わず、認識結果をクリップボードへ残します。",
        "Skips auto-typing and leaves the result on the clipboard.",
        "不自动输入，将识别结果保留在剪贴板。",
        "자동 입력하지 않고 인식 결과를 클립보드에 남깁니다.")
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
      return L.t("カーソル位置に入力しました", "Typed at the cursor", "已输入到光标位置", "커서 위치에 입력했습니다")
    case .copiedOnly:
      return L.t("クリップボードにコピーしました", "Copied to the clipboard", "已复制到剪贴板", "클립보드에 복사했습니다")
    case .copiedNoAccessibility:
      return L.t(
        "アクセシビリティ権限が無効のためコピーしました",
        "Copied instead — the Accessibility permission is not working",
        "辅助功能权限无效，已改为复制",
        "손쉬운 사용 권한이 없어 복사했습니다")
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
