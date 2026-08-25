import Foundation

enum TextPostProcessor {
  static func process(
    _ input: String,
    localeIdentifier: String,
    spokenCommandsEnabled: Bool = true
  ) -> String {
    var text =
      input
      .replacingOccurrences(of: "\u{00a0}", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if spokenCommandsEnabled {
      text = applySpokenFormattingCommands(text, localeIdentifier: localeIdentifier)
    }

    text = replace(pattern: #"[ \t]+"#, in: text, with: " ")
    text = replace(pattern: #" *\n *"#, in: text, with: "\n")
    text = replace(pattern: #"\n{3,}"#, in: text, with: "\n\n")

    if localeIdentifier.hasPrefix("ja") || localeIdentifier.hasPrefix("zh") {
      text = replace(pattern: #"\s+([、。！？：；，。！？])"#, in: text, with: "$1")
      text = replace(pattern: #"([（「『【])\s+"#, in: text, with: "$1")
      text = replace(pattern: #"\s+([）」』】])"#, in: text, with: "$1")
    } else {
      text =
        text
        .components(separatedBy: "\n")
        .map(capitalizingFirstLetter)
        .joined(separator: "\n")
    }

    return text
  }

  private static func applySpokenFormattingCommands(
    _ source: String,
    localeIdentifier: String
  ) -> String {
    var text = source
    if localeIdentifier.hasPrefix("ja") {
      text = replace(
        pattern: #"(新しい段落|次の段落|段落を変えて)"#,
        in: text,
        with: "\n\n"
      )
      text = replace(pattern: #"(改行して|改行)"#, in: text, with: "\n")
    } else if localeIdentifier.hasPrefix("en") {
      text = replace(
        pattern: #"(?i)\b(new paragraph|next paragraph)\b"#,
        in: text,
        with: "\n\n"
      )
      text = replace(
        pattern: #"(?i)\b(new line|line break)\b"#,
        in: text,
        with: "\n"
      )
    }
    return text
  }

  private static func replace(pattern: String, in source: String, with replacement: String)
    -> String
  {
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
      return source
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    return expression.stringByReplacingMatches(in: source, range: range, withTemplate: replacement)
  }

  private static func capitalizingFirstLetter(_ source: String) -> String {
    guard let first = source.first, first.isLetter, first.isLowercase else { return source }
    var result = source
    result.replaceSubrange(result.startIndex...result.startIndex, with: String(first).uppercased())
    return result
  }
}
