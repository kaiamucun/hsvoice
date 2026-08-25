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
    XCTAssertEqual(result, "これは テストです。 次です！")
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
