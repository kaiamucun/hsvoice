import Foundation

enum TextPostProcessor {

  /// Character class used to decide whether a space sits *between* two CJK
  /// characters and is therefore an artifact of recognition rather than real
  /// spacing. Latin words and digits are deliberately excluded: a space around
  /// them inside Japanese text is correct and must survive.
  private static let cjk =
    #"[\p{Han}\p{Hiragana}\p{Katakana}ー々〆〤、。，．！？：；（）「」『』【】〔〕・…〜]"#

  /// Spaces and tabs only — never a newline.
  ///
  /// The punctuation rules below used `\s`, which swallowed the line breaks that
  /// the spoken layout commands had just inserted: "…ですが改行して、次は" lost its
  /// break entirely. Tidying spacing must never undo a break the user asked for.
  private static let horizontalSpace = "[ \t\u{3000}]"

  /// Every pattern is a literal, so compiling once at load removes an
  /// `NSRegularExpression` build from each of the eight or so substitutions that
  /// run on every dictation — and removes the silent `try?` fallback that used to
  /// return the text unchanged if compilation ever failed.
  private enum Patterns {
    static let horizontalWhitespace = expression(#"[ \t]+"#)
    static let paddedNewline = expression(#" *\n *"#)
    static let excessBlankLines = expression(#"\n{3,}"#)

    // Japanese / Chinese
    static let spaceBeforeCJKPunctuation = expression(
      "\(TextPostProcessor.horizontalSpace)+([、。！？：；，])"
    )
    static let spaceAfterOpeningBracket = expression(
      "([（「『【〔])\(TextPostProcessor.horizontalSpace)+"
    )
    static let spaceBeforeClosingBracket = expression(
      "\(TextPostProcessor.horizontalSpace)+([）」』】〕])"
    )
    static let spaceBetweenCJK = expression(
      "(?<=\(TextPostProcessor.cjk))\(TextPostProcessor.horizontalSpace)+"
      + "(?=\(TextPostProcessor.cjk))"
    )
    static let commaBeforeNewline = expression(#"[、，,][ \t]*\n"#)
    static let commaAfterNewline = expression(#"\n[ \t]*[、，,]"#)

    // Latin scripts
    static let spaceBeforeLatinPunctuation = expression(
      "\(TextPostProcessor.horizontalSpace)+([.,!?;:])"
    )

    // Spoken layout commands
    static let japaneseParagraph = expression(#"(新しい段落|次の段落|段落を変えて)"#)
    static let japaneseNewline = expression(#"(改行して|改行)"#)
    static let englishParagraph = expression(#"(?i)\b(new paragraph|next paragraph)\b"#)
    static let englishNewline = expression(#"(?i)\b(new line|line break)\b"#)

    private static func expression(_ pattern: String) -> NSRegularExpression {
      // These are compile-time literals, so a failure is a programming error. It
      // should stop the first test run rather than silently disable text cleanup
      // in the shipped app, which is what the previous `try?` fallback did.
      guard let expression = try? NSRegularExpression(pattern: pattern) else {
        preconditionFailure("Invalid built-in pattern: \(pattern)")
      }
      return expression
    }
  }

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

    text = Patterns.horizontalWhitespace.replacing(in: text, with: " ")
    text = Patterns.paddedNewline.replacing(in: text, with: "\n")
    text = Patterns.excessBlankLines.replacing(in: text, with: "\n\n")

    if usesCJKSpacing(localeIdentifier) {
      text = applyCJKSpacing(text)
    } else {
      text = Patterns.spaceBeforeLatinPunctuation.replacing(in: text, with: "$1")
      text = capitalizingSentences(text)
    }

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func usesCJKSpacing(_ localeIdentifier: String) -> Bool {
    localeIdentifier.hasPrefix("ja") || localeIdentifier.hasPrefix("zh")
  }

  private static func applyCJKSpacing(_ source: String) -> String {
    var text = Patterns.spaceBeforeCJKPunctuation.replacing(in: source, with: "$1")
    text = Patterns.spaceAfterOpeningBracket.replacing(in: text, with: "$1")
    text = Patterns.spaceBeforeClosingBracket.replacing(in: text, with: "$1")

    // Apple's recognizer often splits Japanese into space-separated chunks. A space
    // with CJK on both sides is never intended, while a space next to a Latin word
    // or a number is, so only the former is removed.
    text = Patterns.spaceBetweenCJK.replacing(in: text, with: "")

    // A spoken line break usually follows a comma the speaker did not mean to keep
    // ("〜ですが、改行して〜"), which would otherwise strand punctuation at the end
    // or the start of a line.
    text = Patterns.commaBeforeNewline.replacing(in: text, with: "\n")
    text = Patterns.commaAfterNewline.replacing(in: text, with: "\n")
    return text
  }

  private static func applySpokenFormattingCommands(
    _ source: String,
    localeIdentifier: String
  ) -> String {
    var text = source
    if localeIdentifier.hasPrefix("ja") {
      text = Patterns.japaneseParagraph.replacing(in: text, with: "\n\n")
      text = Patterns.japaneseNewline.replacing(in: text, with: "\n")
    } else if localeIdentifier.hasPrefix("en") {
      text = Patterns.englishParagraph.replacing(in: text, with: "\n\n")
      text = Patterns.englishNewline.replacing(in: text, with: "\n")
    }
    return text
  }

  /// Capitalizes the start of every line and of every sentence that follows a
  /// full stop.
  ///
  /// Only line starts were capitalized before, so a spoken "new line" in the middle
  /// of a thought left the following sentence lowercase. A boundary requires
  /// whitespace after the punctuation, which keeps URLs and decimals ("3.5") intact.
  private static func capitalizingSentences(_ source: String) -> String {
    var result = ""
    result.reserveCapacity(source.count)
    var startsSentence = true
    var followsTerminator = false

    for character in source {
      if startsSentence, character.isLetter, character.isLowercase {
        result.append(contentsOf: String(character).uppercased())
        startsSentence = false
        followsTerminator = false
        continue
      }

      if character.isWhitespace {
        if followsTerminator || character.isNewline {
          startsSentence = true
        }
      } else {
        startsSentence = false
        followsTerminator = character == "." || character == "!" || character == "?"
      }
      result.append(character)
    }

    return result
  }
}

extension NSRegularExpression {
  fileprivate func replacing(in source: String, with template: String) -> String {
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    return stringByReplacingMatches(in: source, range: range, withTemplate: template)
  }
}
