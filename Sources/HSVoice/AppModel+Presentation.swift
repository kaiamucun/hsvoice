import Foundation

/// Read-only presentation helpers.
///
/// These derive display strings from state that `AppModel` already owns and never
/// mutate anything, so keeping them out of the state machine makes both halves
/// easier to read. `AppModel` itself is then only lifecycle, recording flow, and
/// the transitions between voice states.
extension AppModel {

  var isListening: Bool { state == .listening }

  var menuBarSymbol: String {
    state.symbolName
  }

  var shortcutDisplayText: String {
    settings.shortcutChoice.displayName
  }

  var formattedRecordingDuration: String {
    let seconds = max(0, Int(recordingDuration.rounded(.down)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  var recordingProgress: Double {
    min(1, recordingDuration / RecordingLimit.maximumDuration)
  }

  var versionDisplay: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Development"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "HS Voice \(version) (\($0))" } ?? "HS Voice \(version)"
  }

  var stateDetail: String {
    switch state {
    case .idle:
      return L.t(
        "\(shortcutDisplayText)でどこからでも音声入力",
        "Dictate anywhere with \(shortcutDisplayText)",
        "按\(shortcutDisplayText)即可在任何位置语音输入",
        "\(shortcutDisplayText)로 어디서나 음성 입력")
    case .requestingPermission:
      return L.t(
        "macOSの確認に応答してください", "Please respond to the macOS prompt",
        "请回应macOS的确认对话框", "macOS 확인 창에 응답해 주세요")
    case .listening:
      if settings.insertionMode == .clipboardOnly {
        return L.t("クリップボードへコピー", "Copying to clipboard", "复制到剪贴板", "클립보드에 복사")
          + " • \(formattedRecordingDuration)"
      }
      return targetApplicationName.map {
        L.t("\($0)へ入力", "Typing into \($0)", "输入到\($0)", "\($0)에 입력")
          + " • \(formattedRecordingDuration)"
      }
        ?? L.t("録音中", "Recording", "录音中", "녹음 중") + " • \(formattedRecordingDuration)"
    case .processing:
      return L.t("句読点と空白を整えています", "Tidying punctuation and spacing", "正在整理标点与空格", "문장 부호와 공백을 정리 중")
    case .success(let message), .error(let message):
      return message
    }
  }
}
