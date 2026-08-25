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
}
