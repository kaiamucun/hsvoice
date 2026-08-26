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
      return "\(shortcutDisplayText)でどこからでも音声入力"
    case .requestingPermission:
      return "macOSの確認に応答してください"
    case .listening:
      if settings.insertionMode == .clipboardOnly {
        return "クリップボードへコピー • \(formattedRecordingDuration)"
      }
      return targetApplicationName.map { "\($0)へ入力 • \(formattedRecordingDuration)" }
        ?? "録音中 • \(formattedRecordingDuration)"
    case .processing:
      return "句読点と空白を整えています"
    case .success(let message), .error(let message):
      return message
    }
  }
}
