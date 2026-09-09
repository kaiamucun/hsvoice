import Foundation

// A standalone harness for synthetic dictation only. It uses the app's actual
// RefinementService and the on-device model; no API keys or network client.
enum L {
  static func t(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String { ja }
}

struct EvaluationCase: Codable {
  let id: String
  let input: String
  let vocabulary: [String]
  let expectedQualities: [String]
  let applicationName: String?

  init(id: String, input: String, vocabulary: [String], expectedQualities: [String], applicationName: String? = nil) {
    self.id = id
    self.input = input
    self.vocabulary = vocabulary
    self.expectedQualities = expectedQualities
    self.applicationName = applicationName
  }
}

struct EvaluationResult: Codable {
  let sample: EvaluationCase
  let latencySeconds: Double
  let refinedOutput: String?
  let insertedText: String
  let usedFallback: Bool
  let serviceStatus: String?
}

struct EvaluationReport: Codable {
  let label: String
  let createdAt: String
  let operatingSystem: String
  let availability: String
  let syntheticInputOnly: Bool
  let engine: String
  let mode: String
  let suite: String
  let applicationContextEnabled: Bool
  let results: [EvaluationResult]
}

@main
struct RefinementEvaluation {
  static let cases: [EvaluationCase] = [
    .init(id: "short-filler", input: "えっと了解", vocabulary: [], expectedQualities: ["Remove the filler", "Preserve the acknowledgement"]),
    .init(id: "corrected-time", input: "えっと、明日の会議は3時、いや4時に変更してください。", vocabulary: [], expectedQualities: ["Use the final corrected time, 4", "Keep tomorrow and the change request"]),
    .init(id: "negation", input: "契約はまだ承認していません。送付しないでください。", vocabulary: [], expectedQualities: ["Preserve the unapproved status", "Preserve the request not to send"]),
    .init(id: "uncertainty", input: "たぶん金曜までには終わると思いますが、まだ確定ではありません。", vocabulary: [], expectedQualities: ["Preserve uncertainty", "Do not convert the estimate into a commitment"]),
    .init(id: "names-numbers", input: "えー、佐藤さんにHS Voiceの見積もり12万5000円を、9月18日までに送ってください。", vocabulary: ["HS Voice", "佐藤"], expectedQualities: ["Preserve the recipient and product", "Preserve 125000 yen and September 18", "Keep the send request"]),
    .init(id: "mixed-english", input: "Slackのreleaseチャンネルに、APIのtimeoutを30秒に変更したって共有してください。", vocabulary: ["Slack", "API", "timeout", "release"], expectedQualities: ["Preserve the channel and technical terms", "Preserve 30 seconds and the sharing request", "Keep Japanese as the main language"]),
    .init(id: "disordered-clauses", input: "資料を送ってください、田中さんに。今日中でお願いします。あ、送る前に数字だけ確認してください。", vocabulary: ["田中"], expectedQualities: ["Keep Tanaka as the recipient and today as the deadline", "Place checking numbers before sending", "Do not invent actions or details"]),
  ]

  // Chosen independently after the initial run. These fixtures were not copied
  // from the replacement prompt or supplied verbatim to its implementation agent.
  static let heldoutCases: [EvaluationCase] = [
    .init(id: "heldout-request-and-commitment", input: "えー、青木さん、請求書の宛名を法人名に直してもらえますか。支払いはこちらで対応します。", vocabulary: ["青木"], expectedQualities: ["Keep the request to Aoki to change the invoice addressee", "Keep the speaker's separate commitment to handle payment", "Do not swap the responsible actors"]),
    .init(id: "heldout-actor-negation", input: "私は削除していません。森さんが削除したかどうかも、まだ確認できていません。", vocabulary: ["森"], expectedQualities: ["Keep the speaker's explicit denial of deleting", "Keep uncertainty about Mori's action", "Do not claim that nothing was deleted or that Mori deleted it"]),
    .init(id: "heldout-date-time-correction", input: "予約は10月6日の午前10時、すみません、10月8日の午後2時でお願いします。", vocabulary: [], expectedQualities: ["Retain only the corrected booking date of October 8", "Retain only the corrected time of 2 PM", "Keep the booking request as a request"]),
    .init(id: "heldout-uncertain-decision", input: "新しい案に切り替えるかもしれませんが、費用を見てから決めたいので、今の案も残しておいてください。", vocabulary: [], expectedQualities: ["Keep switching to the new plan as a possibility", "Keep reviewing cost before deciding", "Keep the request to retain the current plan"]),
    .init(id: "heldout-casual-messages", input: "あー、さっきの写真ありがと。めっちゃよかった。また週末あそぼうね。", vocabulary: [], expectedQualities: ["Remove the opening hesitation", "Preserve the friendly casual voice in Messages", "Keep the photo thanks, positive reaction, and weekend invitation", "Do not force formal business wording"], applicationName: "Messages"),
  ]

  // Final validation was authored after v1 results but before the v2 prompt.
  // These texts are not shared with the tuning agent before the final run.
  static let finalCases: [EvaluationCase] = [
    .init(id: "final-corrected-quantity", input: "納品数は18個、違います、28個でお願いします。", vocabulary: [], expectedQualities: ["Keep only the corrected quantity of 28 items", "Remove the superseded 18 and correction phrase", "Preserve the delivery quantity request"]),
    .init(id: "final-fillers-polite-request", input: "えっと、昨日のデモのリンクを、あの、もう一度送っていただけますか。", vocabulary: [], expectedQualities: ["Remove both hesitation fillers", "Keep yesterday's demo, the link, and the repeat-send request", "Preserve the polite request rather than making a promise"]),
    .init(id: "final-disordered-clauses", input: "在庫を確認してください。発注の前に。対象は青いケーブルです。", vocabulary: [], expectedQualities: ["Connect the fragments into a natural request", "Keep checking inventory before ordering", "Keep blue cables as the subject", "Do not invent an order placement or change who must check"]),
  ]

  static func main() async throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2 || args.count == 3 else {
      throw NSError(domain: "RefinementEvaluation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Usage: binary LABEL OUTPUT.json [--availability-only]"])
    }
    let availability = RefinementService.availability()
    let status = String(describing: availability)
    let availabilityOnly = args.count == 3 && args[2] == "--availability-only"
    let suite = ProcessInfo.processInfo.environment["HSVOICE_REFINEMENT_EVALUATION_SUITE"] ?? "baseline"
    let selectedCases: [EvaluationCase]
    switch suite {
    case "baseline": selectedCases = cases
    case "heldout": selectedCases = heldoutCases
    case "final": selectedCases = finalCases
    case "all": selectedCases = cases + heldoutCases + finalCases
    default:
      throw NSError(domain: "RefinementEvaluation", code: 2, userInfo: [NSLocalizedDescriptionKey: "HSVOICE_REFINEMENT_EVALUATION_SUITE must be baseline, heldout, final, or all"])
    }
    #if REFINEMENT_APPLICATION_CONTEXT
      let applicationContextEnabled = true
    #else
      let applicationContextEnabled = false
    #endif
    var results: [EvaluationResult] = []
    writeProgress("On-device model availability: \(status)")
    if availability == .available && !availabilityOnly {
      for sample in selectedCases {
        let start = ContinuousClock.now
        #if REFINEMENT_DETAILED_RESULT
          #if REFINEMENT_APPLICATION_CONTEXT
            let detailed = await RefinementService.refineWithResult(sample.input, mode: .cleanup, vocabulary: sample.vocabulary, applicationName: sample.applicationName)
          #else
            let detailed = await RefinementService.refineWithResult(sample.input, mode: .cleanup, vocabulary: sample.vocabulary)
          #endif
          let refined = detailed.text
          let serviceStatus: String? = String(describing: detailed.status)
        #elseif REFINEMENT_APPLICATION_CONTEXT
          let refined = await RefinementService.refine(sample.input, mode: .cleanup, vocabulary: sample.vocabulary, applicationName: sample.applicationName)
          let serviceStatus: String? = nil
        #else
          let refined = await RefinementService.refine(sample.input, mode: .cleanup, vocabulary: sample.vocabulary)
          let serviceStatus: String? = nil
        #endif
        let duration = start.duration(to: .now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        results.append(.init(sample: sample, latencySeconds: seconds, refinedOutput: refined, insertedText: refined ?? sample.input, usedFallback: refined == nil, serviceStatus: serviceStatus))
        writeProgress("\(sample.id): \(String(format: "%.3f", seconds))s; fallback=\(refined == nil); status=\(serviceStatus ?? "not exposed"); output=\(refined ?? sample.input)")
      }
    }
    let report = EvaluationReport(label: args[0], createdAt: ISO8601DateFormatter().string(from: Date()), operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString, availability: status, syntheticInputOnly: true, engine: "Apple FoundationModels (on-device)", mode: "cleanup", suite: suite, applicationContextEnabled: applicationContextEnabled, results: results)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(report)
    let destination = URL(fileURLWithPath: args[1])
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: destination)
    writeProgress("Report written to \(destination.path)")
  }

  static func writeProgress(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }
}
