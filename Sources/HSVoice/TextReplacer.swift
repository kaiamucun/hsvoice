import Foundation

/// One custom-dictionary entry: the correct spelling of a name or term, plus
/// the forms the recognizer tends to produce for it ("読み・誤認識例").
///
/// The spoken forms are what makes the dictionary work with the high-accuracy
/// engine, which has no contextual-string hints: the transcript is corrected
/// after recognition instead. The term itself is still handed to the classic
/// engine as a hint.
struct DictionaryEntry: Codable, Equatable, Identifiable {
  var id: UUID
  var term: String
  /// Comma-separated (`,` `、` `，`) alternatives the recognizer produces.
  var spokenForms: String

  init(id: UUID = UUID(), term: String, spokenForms: String = "") {
    self.id = id
    self.term = term
    self.spokenForms = spokenForms
  }

  var spokenFormList: [String] {
    spokenForms
      .components(separatedBy: CharacterSet(charactersIn: ",、，"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var trimmedTerm: String { term.trimmingCharacters(in: .whitespacesAndNewlines) }
  var isBlank: Bool { trimmedTerm.isEmpty }
}

/// A spoken trigger phrase that is swapped for a longer text: an email
/// address, a meeting link, a greeting that is typed a dozen times a day.
struct ReplacementRule: Codable, Equatable, Identifiable {
  var id: UUID
  var trigger: String
  var replacement: String

  init(id: UUID = UUID(), trigger: String, replacement: String) {
    self.id = id
    self.trigger = trigger
    self.replacement = replacement
  }

  var trimmedTrigger: String { trigger.trimmingCharacters(in: .whitespacesAndNewlines) }
  var isBlank: Bool { trimmedTrigger.isEmpty }
}

/// Applies the custom dictionary and the replacement rules to a transcript.
///
/// Built once per recording (the patterns are compiled in `init`) and applied
/// to every partial update and to the final text, so what the user sees while
/// speaking already carries the corrections.
///
/// Order: dictionary first, then replacements — a corrected term can itself be
/// a replacement trigger. Within each group longer patterns win, so an entry
/// for "ジョプトゲームズ" is never pre-empted by one for "ジョプト".
struct TextReplacer {
  static let dictionaryLimit = 500
  static let replacementLimit = 200

  private struct Substitution {
    let expression: NSRegularExpression
    let template: String
  }

  private let substitutions: [Substitution]

  init(dictionary: [DictionaryEntry], replacements: [ReplacementRule]) {
    let dictionaryPairs: [(String, String)] = dictionary.prefix(Self.dictionaryLimit).flatMap {
      entry -> [(String, String)] in
      let term = entry.trimmedTerm
      guard !term.isEmpty else { return [] }
      return entry.spokenFormList.filter { $0 != term }.map { ($0, term) }
    }
    let replacementPairs: [(String, String)] = replacements.prefix(Self.replacementLimit).compactMap {
      rule in
      let trigger = rule.trimmedTrigger
      guard !trigger.isEmpty else { return nil }
      return (trigger, rule.replacement)
    }
    substitutions = Self.compile(dictionaryPairs) + Self.compile(replacementPairs)
  }

  var isEmpty: Bool { substitutions.isEmpty }

  func apply(_ text: String) -> String {
    guard !substitutions.isEmpty, !text.isEmpty else { return text }
    var result = text
    for substitution in substitutions {
      let range = NSRange(result.startIndex..<result.endIndex, in: result)
      result = substitution.expression.stringByReplacingMatches(
        in: result, range: range, withTemplate: substitution.template)
    }
    return result
  }

  private static func compile(_ pairs: [(String, String)]) -> [Substitution] {
    pairs
      .sorted { $0.0.count > $1.0.count }
      .compactMap { pattern, replacement in
        guard let expression = expression(for: pattern) else { return nil }
        return Substitution(
          expression: expression,
          template: NSRegularExpression.escapedTemplate(for: replacement))
      }
  }

  /// A Latin word only matches at word boundaries ("mail" must not fire inside
  /// "email"); Japanese and Chinese have no boundaries, so CJK patterns match
  /// anywhere. Matching ignores case so "Work Mail" and "work mail" are one trigger.
  private static func expression(for pattern: String) -> NSRegularExpression? {
    var source = NSRegularExpression.escapedPattern(for: pattern)
    if let first = pattern.unicodeScalars.first, isLatinWordScalar(first) {
      source = "(?<![\\p{Latin}\\p{N}])" + source
    }
    if let last = pattern.unicodeScalars.last, isLatinWordScalar(last) {
      source += "(?![\\p{Latin}\\p{N}])"
    }
    return try? NSRegularExpression(pattern: source, options: [.caseInsensitive])
  }

  private static func isLatinWordScalar(_ scalar: Unicode.Scalar) -> Bool {
    if scalar.value >= 0x30 && scalar.value <= 0x39 { return true }
    return scalar.value < 0x250 && scalar.properties.isAlphabetic
  }
}
