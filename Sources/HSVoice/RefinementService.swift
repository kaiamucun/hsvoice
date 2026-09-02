import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// What the dictation transcript is turned into before insertion.
enum RefinementMode: String, CaseIterable, Identifiable, Codable {
  case cleanup
  case summarize

  var id: String { rawValue }

  var label: String {
    switch self {
    case .cleanup:
      return L.t("整形（ビジネス文に仕上げ）", "Polish (business-ready text)", "润色（商务文体）", "다듬기（비즈니스 문장）")
    case .summarize: return L.t("要約", "Summarize", "摘要", "요약")
    }
  }

  var detail: String {
    switch self {
    case .cleanup:
      return L.t(
        "フィラーや言い直しを取り除き、そのまま人に送れるきちんとした文章に仕上げます。内容は変えません。",
        "Removes fillers and self-corrections and polishes the text into something you can send as-is. The content itself is unchanged.",
        "去除口头语和改口，将文本润色为可直接发送的正式文字。内容本身不变。",
        "군말과 정정 표현을 제거하고 그대로 보낼 수 있는 정돈된 문장으로 다듬습니다. 내용은 바뀌지 않습니다.")
    case .summarize:
      return L.t(
        "話した内容を、要点だけの短い文章にまとめてから入力します。",
        "Condenses what you said into a short summary before inserting it.",
        "先将所说内容浓缩为要点摘要，再进行输入。",
        "말한 내용을 요점만 담은 짧은 문장으로 정리한 뒤 입력합니다.")
    }
  }
}

/// Why Apple Intelligence refinement can or cannot run right now.
enum RefinementAvailability: Equatable {
  case available
  case osTooOld
  case appleIntelligenceOff
  case deviceNotSupported
  case modelNotReady
  case unavailable
}

/// On-device transcript refinement via Apple Intelligence (FoundationModels).
///
/// Every entry point degrades to "use the raw transcript": `refine` returns
/// `nil` on an old OS, a disabled model, a guardrail refusal, an error, or a
/// timeout — the caller then inserts the unrefined text, so dictation itself
/// can never be broken by this feature.
enum RefinementService {

  /// The OS ships the FoundationModels framework (macOS 26+). Says nothing
  /// about whether Apple Intelligence is enabled — see `availability()`.
  static var isSupported: Bool {
    #if canImport(FoundationModels)
      if #available(macOS 26.0, *) { return true }
    #endif
    return false
  }

  static func availability() -> RefinementAvailability {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *) else { return .osTooOld }
      let availability = SystemLanguageModel.default.availability
      if case .available = availability { return .available }
      if case .unavailable(let reason) = availability {
        switch reason {
        case .deviceNotEligible: return .deviceNotSupported
        case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
        case .modelNotReady: return .modelNotReady
        @unknown default: return .unavailable
        }
      }
      return .unavailable
    #else
      return .osTooOld
    #endif
  }

  /// Loads the model into memory ahead of the first request. Called when a
  /// recording starts so the refinement after it doesn't pay the cold-start.
  static func prewarm() {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *) else { return }
      guard case .available = SystemLanguageModel.default.availability else { return }
      Task.detached(priority: .utility) {
        LanguageModelSession().prewarm()
      }
    #endif
  }

  /// Refinement must never hang the pipeline: past this, the raw text wins.
  private static let timeout: TimeInterval = 30

  /// Below this, cleanup can't remove anything meaningful and summarizing is
  /// pointless — skip the model round-trip entirely.
  private static let minimumLength = 8

  /// Returns the refined text, or `nil` when the raw transcript should be used
  /// unchanged (unsupported OS, model unavailable, error, refusal, timeout, or
  /// an input too short to be worth a model call).
  static func refine(
    _ text: String, mode: RefinementMode, customInstructions: String = "",
    vocabulary: [String] = []
  ) async -> String? {
    #if canImport(FoundationModels)
      guard #available(macOS 26.0, *) else { return nil }
      guard case .available = SystemLanguageModel.default.availability else { return nil }
      guard text.count >= minimumLength else { return nil }

      // A short dictation has nothing to summarize — forcing it produced
      // awkward over-compressed output, so short inputs get polished instead.
      let effectiveMode: RefinementMode =
        (mode == .summarize && text.count < 40) ? .cleanup : mode

      return await withTaskGroup(of: String?.self) { group in
        group.addTask {
          await respond(
            to: text, mode: effectiveMode, customInstructions: customInstructions,
            vocabulary: vocabulary)
        }
        group.addTask {
          try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
          return nil
        }
        // First finisher decides; normally the model, the timer only on a hang.
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
      }
    #else
      return nil
    #endif
  }

  #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func respond(
      to text: String, mode: RefinementMode, customInstructions: String, vocabulary: [String]
    ) async -> String? {
      do {
        // A fresh session per request: sessions accumulate their transcript as
        // context, so reuse would let one dictation bleed into the next.
        let session = LanguageModelSession(
          instructions: instructions(
            for: mode, customInstructions: customInstructions, vocabulary: vocabulary))
        let response = try await session.respond(
          to: "次の文字起こしを処理してください。\n\n\(text)",
          options: GenerationOptions(temperature: 0.1)
        )
        let refined = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return refined.isEmpty ? nil : refined
      } catch {
        // Guardrail refusals, context overflow, cancellation — all mean
        // "insert the raw transcript", never an error the user has to see.
        return nil
      }
    }

    /// The mode's base rules, then the dictionary spellings, then the user's own
    /// instructions last so they take precedence over everything above them.
    static func instructions(
      for mode: RefinementMode, customInstructions: String = "", vocabulary: [String] = []
    ) -> String {
      var text = baseInstructions(for: mode)
      if !vocabulary.isEmpty {
        text += "\n固有名詞・製品名・専門用語は必ず次の表記に合わせる: " + vocabulary.joined(separator: ", ")
      }
      let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
      if !custom.isEmpty {
        text += "\n利用者からの追加指示（上のルールと矛盾する場合はこちらを優先する）:\n" + custom
      }
      return text
    }

    private static func baseInstructions(for mode: RefinementMode) -> String {
      switch mode {
      case .cleanup:
        return """
          あなたは優秀なビジネスアシスタントです。音声入力の文字起こしを、同僚や取引先にそのまま送信できる、きちんとしたビジネス文に仕上げます。
          ルール:
          - 「えー」「あの」「えっと」「なんか」などのフィラー（言いよどみ）と無意味な繰り返しをすべて取り除く
          - 言い直しがあれば、最終的に言った内容だけを残す
          - 話し言葉を自然な書き言葉に直す（例:「っていう」→「という」、「じゃなくて」→「ではなく」、「〜みたいな」→「〜のような」）。日本語は丁寧な「です・ます」調に統一する
          - 冗長な言い回しは簡潔にする。ただし日時・名前・数値・依頼内容・決定事項などの情報は一切落とさない
          - 意味を変えない。話者が言っていない内容を付け足さない
          - 文のつながりを整理し、必要に応じて文を分割・結合して読みやすくする。段落や改行を適切に入れる
          - 並列する項目・要点・手順が3つ以上含まれる場合は、改行して「1. 」「2. 」の番号付き箇条書きにまとめる。それ以外は通常の文章のままにする
          - 出力は仕上げた本文のみ。前置き・説明・引用符は付けない
          - 必ず入力と同じ言語で出力する（英語ならビジネスとして自然な英文に、中国語・韓国語も同様）
          """
      case .summarize:
        return """
          あなたは音声メモを整理するアシスタントです。与えられた文字起こしの要点を、無理のない範囲で簡潔にまとめます。
          ルール:
          - 決定事項・依頼・日時・名前・数値などの重要な情報は絶対に落とさない
          - 無理に短くしない。すでに簡潔な発言や、要約すると意味・ニュアンスが失われる発言は、フィラーを取り除いて読みやすく整えるだけにする
          - 長く冗長な発言だけを短くまとめる。全体をおおよそ半分以下にできない場合は、要約ではなく整形にとどめる
          - 要点が3つ以上ある場合は、改行して「1. 」「2. 」の番号付き箇条書きにまとめる。1〜2点なら通常の文章のままにする
          - 話者が言っていない内容を付け足さない
          - 出力は本文のみ。前置き・説明は付けない
          - 必ず入力と同じ言語で出力する
          """
      }
    }
  #endif
}
