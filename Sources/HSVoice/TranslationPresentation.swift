import Foundation

extension TranslationStatus {
  /// Only fixed status codes enter diagnostics; never model output or errors.
  var diagnosticIdentifier: String {
    switch self {
    case .translated(let backend): return "translated_\(backend.rawValue)"
    case .unchanged(let backend): return "unchanged_\(backend.rawValue)"
    case .skippedSameLanguage: return "skipped_same_language"
    case .emptyInput: return "empty_input"
    case .unavailable: return "unavailable"
    case .timedOut: return "timed_out"
    case .cancelled: return "cancelled"
    case .failed: return "failed"
    case .inputTooLong: return "input_too_long"
    }
  }

  var usedOriginalText: Bool {
    switch self {
    case .unavailable, .timedOut, .failed, .inputTooLong: return true
    case .translated, .unchanged, .skippedSameLanguage, .emptyInput, .cancelled: return false
    }
  }

  /// Shown under the last-dictation card. Same-language skips stay silent so
  /// a follow-on AI polish status can take the slot.
  var shouldDisplay: Bool {
    switch self {
    case .skippedSameLanguage, .emptyInput: return false
    default: return true
    }
  }

  var message: String {
    switch self {
    case .translated(.appleTranslation):
      return L.t(
        "端末内の翻訳で変換しました", "Translated on this Mac", "已在本机翻译", "이 Mac에서 번역했습니다")
    case .translated(.appleIntelligence):
      return L.t(
        "端末内AIで翻訳しました", "Translated with on-device AI", "已用设备端AI翻译", "온디바이스 AI로 번역했습니다")
    case .unchanged:
      return L.t(
        "翻訳結果は原文と同じでした", "Translation returned the original text", "翻译结果与原文相同",
        "번역 결과가 원문과 같았습니다")
    case .skippedSameLanguage:
      return L.t(
        "話す言語と出力言語が同じため翻訳しませんでした",
        "Skipped translation — spoken and output languages match",
        "所说语言与输出语言相同，未翻译", "말하는 언어와 출력 언어가 같아 번역하지 않았습니다")
    case .emptyInput:
      return L.t("翻訳する文章がありません", "No text to translate", "没有可翻译的文本", "번역할 문장이 없습니다")
    case .unavailable:
      return L.t(
        "翻訳を利用できないため、認識した文章を使用しました",
        "Translation is unavailable; the original transcript was used",
        "无法使用翻译，已使用原始识别文本",
        "번역을 사용할 수 없어 인식된 원문을 사용했습니다")
    case .timedOut:
      return L.t(
        "翻訳が時間内に終わらず、認識した文章を使用しました",
        "Translation timed out; the original transcript was used",
        "翻译超时，已使用原始识别文本",
        "번역이 시간 내에 끝나지 않아 인식된 원문을 사용했습니다")
    case .cancelled:
      return L.t("翻訳をキャンセルしました", "Translation cancelled", "已取消翻译", "번역을 취소했습니다")
    case .failed:
      return L.t(
        "翻訳に失敗したため、認識した文章を使用しました",
        "Translation failed; the original transcript was used",
        "翻译失败，已使用原始识别文本",
        "번역에 실패하여 인식된 원문을 사용했습니다")
    case .inputTooLong:
      return L.t(
        "文章が長すぎるため、認識した文章を使用しました",
        "The text was too long; the original transcript was used",
        "文本过长，已使用原始识别文本",
        "문장이 너무 길어 인식된 원문을 사용했습니다")
    }
  }
}
