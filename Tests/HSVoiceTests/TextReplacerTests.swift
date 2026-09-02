import XCTest

@testable import HSVoice

final class TextReplacerTests: XCTestCase {
  func testDictionaryCorrectsSpokenFormsToTheTerm() {
    let replacer = TextReplacer(
      dictionary: [DictionaryEntry(term: "JOPTGames", spokenForms: "ジョプトゲームズ, ジョプトゲーム")],
      replacements: [])
    XCTAssertEqual(replacer.apply("ジョプトゲームズの件です"), "JOPTGamesの件です")
    XCTAssertEqual(replacer.apply("ジョプトゲームの件です"), "JOPTGamesの件です")
  }

  func testLongerSpokenFormsWinOverShorterOnes() {
    let replacer = TextReplacer(
      dictionary: [
        DictionaryEntry(term: "JOPT", spokenForms: "ジョプト"),
        DictionaryEntry(term: "JOPTGames", spokenForms: "ジョプトゲームズ"),
      ],
      replacements: [])
    XCTAssertEqual(replacer.apply("ジョプトゲームズとジョプト"), "JOPTGamesとJOPT")
  }

  func testLatinTriggersMatchWholeWordsCaseInsensitively() {
    let replacer = TextReplacer(
      dictionary: [],
      replacements: [ReplacementRule(trigger: "work mail", replacement: "kaia@example.com")])
    XCTAssertEqual(replacer.apply("Send it to Work Mail please"), "Send it to kaia@example.com please")
    XCTAssertEqual(replacer.apply("my network mailbox"), "my network mailbox")
  }

  func testReplacementRulesExpandJapaneseTriggers() {
    let replacer = TextReplacer(
      dictionary: [],
      replacements: [ReplacementRule(trigger: "仕事メール", replacement: "kaia@example.com")])
    XCTAssertEqual(replacer.apply("仕事メールに送ってください"), "kaia@example.comに送ってください")
  }

  func testDictionaryRunsBeforeReplacements() {
    let replacer = TextReplacer(
      dictionary: [DictionaryEntry(term: "仕事メール", spokenForms: "ワークメール")],
      replacements: [ReplacementRule(trigger: "仕事メール", replacement: "kaia@example.com")])
    XCTAssertEqual(replacer.apply("ワークメール"), "kaia@example.com")
  }

  func testBlankEntriesAndSelfReferencesAreIgnored() {
    let replacer = TextReplacer(
      dictionary: [
        DictionaryEntry(term: "   ", spokenForms: "abc"),
        DictionaryEntry(term: "HS Voice", spokenForms: "HS Voice"),
      ],
      replacements: [ReplacementRule(trigger: "", replacement: "x")])
    XCTAssertTrue(replacer.isEmpty)
    XCTAssertEqual(replacer.apply("abc HS Voice"), "abc HS Voice")
  }

  func testReplacementTextIsInsertedLiterally() {
    let replacer = TextReplacer(
      dictionary: [],
      replacements: [ReplacementRule(trigger: "金額", replacement: "$100 (税込) \\1")])
    XCTAssertEqual(replacer.apply("金額です"), "$100 (税込) \\1です")
  }

  func testTermWithoutSpokenFormsChangesNothing() {
    let replacer = TextReplacer(
      dictionary: [DictionaryEntry(term: "HunterSite")], replacements: [])
    XCTAssertTrue(replacer.isEmpty)
    XCTAssertEqual(replacer.apply("ハンターサイト"), "ハンターサイト")
  }
}
