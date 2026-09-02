import XCTest

@testable import HSVoice

final class ActivationPolicyTests: XCTestCase {
  func testHoldStartsOnPressAndStopsOnRelease() {
    XCTAssertEqual(ActivationPolicy.onPress(mode: .hold, isListening: false), .begin)
    XCTAssertEqual(ActivationPolicy.onPress(mode: .hold, isListening: true), .none)
    XCTAssertEqual(ActivationPolicy.onRelease(mode: .hold, isListening: true, heldFor: 0.1), .stop)
    XCTAssertEqual(ActivationPolicy.onRelease(mode: .hold, isListening: false, heldFor: 3), .none)
  }

  func testToggleFlipsOnEveryPressAndIgnoresRelease() {
    XCTAssertEqual(ActivationPolicy.onPress(mode: .toggle, isListening: false), .begin)
    XCTAssertEqual(ActivationPolicy.onPress(mode: .toggle, isListening: true), .stop)
    XCTAssertEqual(ActivationPolicy.onRelease(mode: .toggle, isListening: true, heldFor: 5), .none)
  }

  func testAutoTapIsHandsFreeAndHoldIsPushToTalk() {
    XCTAssertEqual(ActivationPolicy.onPress(mode: .auto, isListening: false), .begin)
    // A tap: released well before the threshold keeps recording.
    XCTAssertEqual(ActivationPolicy.onRelease(mode: .auto, isListening: true, heldFor: 0.12), .none)
    // The next press ends the hands-free recording.
    XCTAssertEqual(ActivationPolicy.onPress(mode: .auto, isListening: true), .stop)
    // A hold: release after the threshold stops, like push-to-talk.
    XCTAssertEqual(
      ActivationPolicy.onRelease(
        mode: .auto, isListening: true, heldFor: ActivationPolicy.autoHoldThreshold), .stop)
    XCTAssertEqual(ActivationPolicy.onRelease(mode: .auto, isListening: true, heldFor: 2), .stop)
  }

  func testAutoReleaseAfterAStoppingPressDoesNothing() {
    XCTAssertEqual(ActivationPolicy.onRelease(mode: .auto, isListening: false, heldFor: 1), .none)
  }
}
