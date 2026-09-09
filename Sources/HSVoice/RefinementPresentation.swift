import Foundation

extension RefinementStatus {
  /// Only fixed status codes enter diagnostics; never model output or errors.
  var diagnosticIdentifier: String {
    switch self {
    case .refined: return "refined"
    case .unchanged: return "unchanged"
    case .emptyInput: return "empty_input"
    case .unavailable(let reason): return "unavailable_\(reason)"
    case .timedOut: return "timed_out"
    case .cancelled: return "cancelled"
    case .failed: return "failed"
    case .inputTooLong: return "input_too_long"
    }
  }

  var usedOriginalText: Bool {
    switch self {
    case .unavailable, .timedOut, .failed, .inputTooLong: return true
    case .refined, .unchanged, .emptyInput, .cancelled: return false
    }
  }

  var message: String {
    switch self {
    case .refined:
      return L.t("端末内AIで整形しました", "Polished with on-device AI", "已用设备端AI润色", "온디바이스 AI로 다듬었습니다")
    case .unchanged:
      return L.t(
        "端末内AIの処理結果は原文と同じでした", "On-device AI returned the original text", "设备端AI返回了原文",
        "온디바이스 AI가 원문을 그대로 반환했습니다")
    case .emptyInput:
      return L.t("整形する文章がありません", "No text to polish", "没有可润色的文本", "다듬을 문장이 없습니다")
    case .unavailable:
      return L.t(
        "端末内AIを利用できないため、認識した文章を使用しました",
        "On-device AI is unavailable; the original transcript was used",
        "设备端AI不可用，已使用原始识别文本",
        "온디바이스 AI를 사용할 수 없어 인식된 원문을 사용했습니다")
    case .timedOut:
      return L.t(
        "AI整形が時間内に終わらず、認識した文章を使用しました",
        "AI polish timed out; the original transcript was used",
        "AI润色超时，已使用原始识别文本",
        "AI 다듬기 시간이 초과되어 인식된 원문을 사용했습니다")
    case .cancelled:
      return L.t("AI整形をキャンセルしました", "AI polish cancelled", "已取消AI润色", "AI 다듬기를 취소했습니다")
    case .failed:
      return L.t(
        "AI整形に失敗したため、認識した文章を使用しました",
        "AI polish failed; the original transcript was used",
        "AI润色失败，已使用原始识别文本",
        "AI 다듬기에 실패하여 인식된 원문을 사용했습니다")
    case .inputTooLong:
      return L.t(
        "文章またはカスタム指示が長すぎるため、認識した文章を使用しました",
        "The text or custom instructions were too long; the original transcript was used",
        "文本或自定义指令过长，已使用原始识别文本",
        "문장 또는 사용자 지침이 너무 길어 인식된 원문을 사용했습니다")
    }
  }
}
