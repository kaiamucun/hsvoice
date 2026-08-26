import XCTest

@testable import HSVoice

final class SpeechTranscriberTests: XCTestCase {
  func testNewSessionInvalidatesCallbacksFromPriorSession() {
    var tracker = SpeechSessionTracker()
    let first = tracker.begin()

    XCTAssertTrue(tracker.contains(first))

    let second = tracker.begin()
    XCTAssertFalse(tracker.contains(first))
    XCTAssertTrue(tracker.contains(second))

    tracker.invalidate()
    XCTAssertFalse(tracker.contains(second))
  }

  /// Mid-recording finals are banked as segments and joined per language:
  /// Japanese and Chinese seams get no space, space-delimited languages get one.
  func testSegmentJoiningRespectsLocale() {
    XCTAssertEqual(
      SpeechTranscriber.joinSegments("こんにちは。", "続きです。", localeIdentifier: "ja-JP"),
      "こんにちは。続きです。")
    XCTAssertEqual(
      SpeechTranscriber.joinSegments("你好。", "继续。", localeIdentifier: "zh-CN"),
      "你好。继续。")
    XCTAssertEqual(
      SpeechTranscriber.joinSegments("Hello there.", "And more.", localeIdentifier: "en-US"),
      "Hello there. And more.")
  }

  func testSegmentJoiningHandlesEmptySides() {
    XCTAssertEqual(SpeechTranscriber.joinSegments("", "text", localeIdentifier: "ja-JP"), "text")
    XCTAssertEqual(SpeechTranscriber.joinSegments("text", "", localeIdentifier: "en-US"), "text")
    XCTAssertEqual(SpeechTranscriber.joinSegments("", "", localeIdentifier: "en-US"), "")
  }
}
