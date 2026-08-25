import Carbon.HIToolbox
import CoreGraphics
import XCTest

@testable import HSVoice

final class ShortcutChoiceTests: XCTestCase {
  func testShortcutChoicesIncludeFunctionKeyAndUniqueFallbacks() {
    let shortcuts = ShortcutChoice.allCases
    XCTAssertEqual(ShortcutChoice.functionKey.keyLabels, ["fn"])
    XCTAssertTrue(shortcuts.dropFirst().allSatisfy { $0.keyLabels.last == "Space" })
    XCTAssertEqual(Set(shortcuts.map(\.displayName)).count, shortcuts.count)
  }

  func testRecordingLimitProtectsSpeechSession() {
    XCTAssertEqual(RecordingLimit.maximumDuration, 55)
    XCTAssertEqual(RecordingLimit.undoAvailabilityDuration, 8)
  }

  func testFunctionKeyStateTracksPhysicalFnPressAndRelease() {
    var tracker = FunctionKeyStateTracker()

    XCTAssertEqual(tracker.update(isDown: true), .pressed)
    XCTAssertNil(tracker.update(isDown: true))
    XCTAssertEqual(tracker.update(isDown: false), .released)
    XCTAssertNil(tracker.update(isDown: false))
  }

  func testFunctionKeyTransitionsDriveOnePressAndOneReleaseCallback() {
    let manager = GlobalHotKeyManager()
    var transitions: [FunctionKeyTransition] = []
    manager.onPressed = { transitions.append(.pressed) }
    manager.onReleased = { transitions.append(.released) }

    manager.processFunctionFlags([.maskSecondaryFn])
    manager.processFunctionFlags([.maskSecondaryFn])
    manager.processFunctionFlags([])
    manager.processFunctionFlags([])

    XCTAssertEqual(transitions, [.pressed, .released])
  }
}
