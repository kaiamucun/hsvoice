import XCTest

@testable import HSVoice

final class TextPostProcessorTests: XCTestCase {
  func testNormalizesWhitespaceAndPreservesParagraphs() {
    let input = "  hello    world  \n\n\n  second line  "
    let result = TextPostProcessor.process(input, localeIdentifier: "en-US")
    XCTAssertEqual(result, "Hello world\n\nSecond line")
  }

  func testRemovesWhitespaceBeforeJapanesePunctuation() {
    let input = "これは テストです 。 次です ！"
    let result = TextPostProcessor.process(input, localeIdentifier: "ja-JP")
    XCTAssertEqual(result, "これはテストです。次です！")
  }

  func testKeepsSpacingAroundLatinWordsAndNumbersInJapanese() {
    let input = "今日 の 会議 は Zoom で 15 時 から です"
    let result = TextPostProcessor.process(input, localeIdentifier: "ja-JP")
    XCTAssertEqual(result, "今日の会議は Zoom で 15 時からです")
  }

  func testTightensJapaneseBrackets() {
    let input = "彼は 「 これ 」 と 言った 。"
    let result = TextPostProcessor.process(input, localeIdentifier: "ja-JP")
    XCTAssertEqual(result, "彼は「これ」と言った。")
  }

  func testDropsCommaStrandedByASpokenLineBreak() {
    let input = "これはテストですが、改行して次の話です"
    let result = TextPostProcessor.process(input, localeIdentifier: "ja-JP")
    XCTAssertEqual(result, "これはテストですが\n次の話です")
  }

  func testKeepsTheLineBreakWhenTheCommaFollowsTheSpokenCommand() {
    let input = "これはテストですが改行して、次の話です"
    let result = TextPostProcessor.process(input, localeIdentifier: "ja-JP")
    XCTAssertEqual(result, "これはテストですが\n次の話です")
  }

  func testCapitalizesSentencesAfterAFullStop() {
    let input = "hello world . next one !"
    let result = TextPostProcessor.process(input, localeIdentifier: "en-US")
    XCTAssertEqual(result, "Hello world. Next one!")
  }

  func testLeavesDecimalsAndDomainsIntact() {
    XCTAssertEqual(
      TextPostProcessor.process("the file is 3.5 inches wide. it fits", localeIdentifier: "en-US"),
      "The file is 3.5 inches wide. It fits"
    )
    XCTAssertEqual(
      TextPostProcessor.process("visit www.example.com for details", localeIdentifier: "en-US"),
      "Visit www.example.com for details"
    )
  }

  func testEmptyInputRemainsEmpty() {
    XCTAssertEqual(TextPostProcessor.process("   \n ", localeIdentifier: "ja-JP"), "")
  }

  func testJapaneseSpokenLayoutCommands() {
    let input = "最初です新しい段落次です改行最後です"
    let result = TextPostProcessor.process(input, localeIdentifier: "ja-JP")
    XCTAssertEqual(result, "最初です\n\n次です\n最後です")
  }

  func testEnglishSpokenLayoutCommands() {
    let input = "first paragraph new paragraph second line new line final thought"
    let result = TextPostProcessor.process(input, localeIdentifier: "en-US")
    XCTAssertEqual(result, "First paragraph\n\nSecond line\nFinal thought")
  }

  func testSpokenLayoutCommandsCanBeDisabled() {
    let input = "新しい段落について説明します"
    let result = TextPostProcessor.process(
      input,
      localeIdentifier: "ja-JP",
      spokenCommandsEnabled: false
    )
    XCTAssertEqual(result, input)
  }
}
