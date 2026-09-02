import AppKit
import Carbon.HIToolbox
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
  /// Tap for hands-free, hold for push-to-talk — see `ActivationPolicy`.
  case auto

  var id: String { rawValue }

  var label: String {
    switch self {
    case .hold: return L.t("押している間", "While held down", "按住期间", "누르고 있는 동안")
    case .toggle:
      return L.t("押すたびに開始・停止", "Press to start / stop", "按一次开始，再按停止", "누를 때마다 시작·정지")
    case .auto:
      return L.t("自動（短押し／長押し）", "Auto (tap / hold)", "自动（短按／长按）", "자동（짧게／길게）")
    }
  }

  var detail: String {
    switch self {
    case .hold:
      return L.t(
        "キーを押している間だけ録音し、離すと入力します。",
        "Records only while the key is held; releasing it inserts the text.",
        "仅在按住按键时录音，松开即输入。",
        "키를 누르고 있는 동안만 녹음하고, 떼면 입력합니다.")
    case .toggle:
      return L.t(
        "一度押すと録音を開始し、もう一度押すと停止して入力します。",
        "Press once to start recording, press again to stop and insert.",
        "按一次开始录音，再按一次停止并输入。",
        "한 번 누르면 녹음을 시작하고, 다시 누르면 정지하고 입력합니다.")
    case .auto:
      return L.t(
        "短く押すとハンズフリーで録音を続け、もう一度押すと停止します。長押しした場合は離した時点で入力します。",
        "A quick tap keeps recording hands-free until the next tap. Holding the key records only while held.",
        "短按后持续免提录音，再按一次停止；长按时松开即输入。",
        "짧게 누르면 핸즈프리로 계속 녹음하고, 다시 누르면 정지합니다. 길게 누른 경우 떼는 순간 입력합니다.")
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

/// One recorded key combination: a single non-modifier key plus Carbon
/// modifier flags. This is what the settings recorder captures and what
/// `GlobalHotKeyManager` hands to `RegisterEventHotKey`.
struct KeyCombo: Equatable, Hashable, Codable {
  let keyCode: UInt16
  /// Carbon modifier mask (`cmdKey | optionKey | controlKey | shiftKey`).
  let carbonModifiers: UInt32

  var keyLabels: [String] {
    KeyCombo.modifierSymbols(for: carbonModifiers) + [KeyCombo.keyName(for: keyCode)]
  }

  var displayName: String { keyLabels.joined(separator: " ") }

  /// F1–F19 may stand alone; anything else needs at least one modifier so a
  /// global hotkey can never swallow plain typing.
  var isUsableAsGlobalShortcut: Bool {
    carbonModifiers != 0 || KeyCombo.functionRowKeyCodes.contains(keyCode)
  }

  var storageString: String { "\(keyCode):\(carbonModifiers)" }

  init(keyCode: UInt16, carbonModifiers: UInt32) {
    self.keyCode = keyCode
    self.carbonModifiers = carbonModifiers
  }

  init?(storageString: String) {
    let parts = storageString.split(separator: ":")
    guard parts.count == 2,
      let code = UInt16(parts[0]),
      let modifiers = UInt32(parts[1])
    else { return nil }
    self.init(keyCode: code, carbonModifiers: modifiers)
  }

  /// Default for the "re-insert the last dictation" shortcut: ⌃⌥R.
  static let defaultRepeatShortcut = KeyCombo(
    keyCode: UInt16(kVK_ANSI_R),
    carbonModifiers: UInt32(controlKey | optionKey)
  )

  /// Builds the Carbon mask from an AppKit event's modifier flags.
  static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var modifiers: UInt32 = 0
    if flags.contains(.control) { modifiers |= UInt32(controlKey) }
    if flags.contains(.option) { modifiers |= UInt32(optionKey) }
    if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
    if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
    return modifiers
  }

  /// Builds the Carbon mask from a CGEvent's flags (the mouse event tap path).
  static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
    var modifiers: UInt32 = 0
    if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
    if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
    if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
    if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
    return modifiers
  }

  /// Standard macOS display order: ⌃ ⌥ ⇧ ⌘.
  static func modifierSymbols(for carbonModifiers: UInt32) -> [String] {
    var symbols: [String] = []
    if carbonModifiers & UInt32(controlKey) != 0 { symbols.append("⌃") }
    if carbonModifiers & UInt32(optionKey) != 0 { symbols.append("⌥") }
    if carbonModifiers & UInt32(shiftKey) != 0 { symbols.append("⇧") }
    if carbonModifiers & UInt32(cmdKey) != 0 { symbols.append("⌘") }
    return symbols
  }

  static let functionRowKeyCodes: Set<UInt16> = [
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,  // F1–F12
    105, 107, 113, 106, 64, 79, 80,  // F13–F19
  ]

  /// Human-readable label for a virtual key code (ANSI layout names, plus the
  /// JIS keys on Japanese hardware). Unknown codes fall back to "Key NN".
  static func keyName(for keyCode: UInt16) -> String {
    if let name = keyNames[keyCode] { return name }
    return "Key \(keyCode)"
  }

  private static let keyNames: [UInt16: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
    11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
    31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
    45: "N", 46: "M",
    18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6", 25: "9", 26: "7", 28: "8", 29: "0",
    24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
    43: ",", 44: "/", 47: ".", 50: "`",
    36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "esc",
    117: "⌦", 115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
    123: "←", 124: "→", 125: "↓", 126: "↑",
    122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
    101: "F9", 109: "F10", 103: "F11", 111: "F12",
    105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
    93: "¥", 94: "_", 102: "英数", 104: "かな",
    65: "Pad .", 67: "Pad *", 69: "Pad +", 75: "Pad /", 78: "Pad -", 81: "Pad =",
    76: "Enter",
    82: "Pad 0", 83: "Pad 1", 84: "Pad 2", 85: "Pad 3", 86: "Pad 4", 87: "Pad 5",
    88: "Pad 6", 89: "Pad 7", 91: "Pad 8", 92: "Pad 9",
  ]
}

/// A mouse button (middle or a side button) plus modifier keys, recordable as
/// a shortcut just like a key combination. Buttons 0/1 (left/right) are never
/// accepted — a global trigger must not swallow ordinary clicking.
struct MouseButtonCombo: Equatable, Hashable, Codable {
  /// AppKit/CGEvent button number: 2 = middle, 3/4 = the usual side buttons.
  let buttonNumber: Int32
  let carbonModifiers: UInt32

  var keyLabels: [String] {
    KeyCombo.modifierSymbols(for: carbonModifiers) + [MouseButtonCombo.buttonName(buttonNumber)]
  }

  var displayName: String { keyLabels.joined(separator: " ") }

  var isUsableAsGlobalShortcut: Bool { buttonNumber >= 2 }

  var storageString: String { "mouse:\(buttonNumber):\(carbonModifiers)" }

  init(buttonNumber: Int32, carbonModifiers: UInt32) {
    self.buttonNumber = buttonNumber
    self.carbonModifiers = carbonModifiers
  }

  init?(storageString: String) {
    let parts = storageString.split(separator: ":")
    guard parts.count == 3, parts[0] == "mouse",
      let button = Int32(parts[1]),
      let modifiers = UInt32(parts[2])
    else { return nil }
    self.init(buttonNumber: button, carbonModifiers: modifiers)
  }

  /// Buttons are shown 1-based, matching how mice label them (M3 = middle,
  /// M4/M5 = side buttons).
  static func buttonName(_ buttonNumber: Int32) -> String {
    "M\(buttonNumber + 1)"
  }
}

/// Any recordable trigger: a key combination or a mouse button combination.
/// This is what the settings recorder produces and what the repeat shortcut
/// stores.
enum InputCombo: Equatable, Hashable, Codable {
  case key(KeyCombo)
  case mouse(MouseButtonCombo)

  var keyLabels: [String] {
    switch self {
    case .key(let combo): return combo.keyLabels
    case .mouse(let combo): return combo.keyLabels
    }
  }

  var displayName: String { keyLabels.joined(separator: " ") }

  var isUsableAsGlobalShortcut: Bool {
    switch self {
    case .key(let combo): return combo.isUsableAsGlobalShortcut
    case .mouse(let combo): return combo.isUsableAsGlobalShortcut
    }
  }

  /// Key combos keep their bare "keyCode:modifiers" form (the format shipped
  /// first), mouse combos are prefixed "mouse:button:modifiers".
  var storageString: String {
    switch self {
    case .key(let combo): return combo.storageString
    case .mouse(let combo): return combo.storageString
    }
  }

  init?(storageString: String) {
    if let mouse = MouseButtonCombo(storageString: storageString) {
      self = .mouse(mouse)
    } else if let key = KeyCombo(storageString: storageString) {
      self = .key(key)
    } else {
      return nil
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    guard let value = InputCombo(storageString: raw) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unknown input combo: \(raw)")
    }
    self = value
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(storageString)
  }

  static let defaultRepeatShortcut = InputCombo.key(.defaultRepeatShortcut)
}

enum ShortcutChoice: RawRepresentable, Equatable, Hashable, Identifiable, Codable {
  case functionKey
  case optionSpace
  case controlSpace
  case commandShiftSpace
  case controlOptionSpace
  case custom(InputCombo)

  /// The fixed choices shown in the preset menu (the recorder covers the rest).
  static let presets: [ShortcutChoice] = [
    .functionKey, .optionSpace, .controlSpace, .commandShiftSpace, .controlOptionSpace,
  ]

  var id: String { rawValue }

  private static let customPrefix = "custom:"

  var rawValue: String {
    switch self {
    case .functionKey: return "functionKey"
    case .optionSpace: return "optionSpace"
    case .controlSpace: return "controlSpace"
    case .commandShiftSpace: return "commandShiftSpace"
    case .controlOptionSpace: return "controlOptionSpace"
    case .custom(let input): return Self.customPrefix + input.storageString
    }
  }

  init?(rawValue: String) {
    switch rawValue {
    case "functionKey": self = .functionKey
    case "optionSpace": self = .optionSpace
    case "controlSpace": self = .controlSpace
    case "commandShiftSpace": self = .commandShiftSpace
    case "controlOptionSpace": self = .controlOptionSpace
    default:
      guard rawValue.hasPrefix(Self.customPrefix),
        let input = InputCombo(storageString: String(rawValue.dropFirst(Self.customPrefix.count)))
      else { return nil }
      self = .custom(input)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    guard let value = ShortcutChoice(rawValue: raw) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unknown shortcut: \(raw)")
    }
    self = value
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  /// The combo registered with Carbon; `nil` for the fn key, which has its own
  /// event-tap / polling path.
  var keyCombo: KeyCombo? {
    switch self {
    case .functionKey:
      return nil
    case .optionSpace:
      return KeyCombo(keyCode: UInt16(kVK_Space), carbonModifiers: UInt32(optionKey))
    case .controlSpace:
      return KeyCombo(keyCode: UInt16(kVK_Space), carbonModifiers: UInt32(controlKey))
    case .commandShiftSpace:
      return KeyCombo(keyCode: UInt16(kVK_Space), carbonModifiers: UInt32(cmdKey | shiftKey))
    case .controlOptionSpace:
      return KeyCombo(keyCode: UInt16(kVK_Space), carbonModifiers: UInt32(controlKey | optionKey))
    case .custom(let input):
      if case .key(let combo) = input { return combo }
      return nil
    }
  }

  /// The recorded trigger in its general form; `nil` only for the fn key.
  var inputCombo: InputCombo? {
    switch self {
    case .functionKey: return nil
    case .custom(let input): return input
    default: return keyCombo.map { .key($0) }
    }
  }

  var keyLabels: [String] {
    switch self {
    case .functionKey: return ["fn"]
    default: return inputCombo?.keyLabels ?? []
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
