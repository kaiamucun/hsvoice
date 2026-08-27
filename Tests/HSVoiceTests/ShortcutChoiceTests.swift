import Carbon.HIToolbox
import CoreGraphics
import XCTest

@testable import HSVoice

final class ShortcutChoiceTests: XCTestCase {
  func testShortcutChoicesIncludeFunctionKeyAndUniqueFallbacks() {
    let shortcuts = ShortcutChoice.presets
    XCTAssertEqual(ShortcutChoice.functionKey.keyLabels, ["fn"])
    XCTAssertTrue(shortcuts.dropFirst().allSatisfy { $0.keyLabels.last == "Space" })
    XCTAssertEqual(Set(shortcuts.map(\.displayName)).count, shortcuts.count)
  }

  func testPresetRawValuesStayStableForStoredSettings() {
    // These strings live in UserDefaults of existing installs.
    XCTAssertEqual(ShortcutChoice(rawValue: "functionKey"), .functionKey)
    XCTAssertEqual(ShortcutChoice(rawValue: "optionSpace"), .optionSpace)
    XCTAssertEqual(ShortcutChoice(rawValue: "controlSpace"), .controlSpace)
    XCTAssertEqual(ShortcutChoice(rawValue: "commandShiftSpace"), .commandShiftSpace)
    XCTAssertEqual(ShortcutChoice(rawValue: "controlOptionSpace"), .controlOptionSpace)
    for preset in ShortcutChoice.presets {
      XCTAssertEqual(ShortcutChoice(rawValue: preset.rawValue), preset)
    }
  }

  func testCustomShortcutRoundTripsThroughRawValue() {
    let combo = KeyCombo(keyCode: 9, carbonModifiers: UInt32(cmdKey | shiftKey))  // ⇧⌘V
    let choice = ShortcutChoice.custom(.key(combo))
    XCTAssertEqual(ShortcutChoice(rawValue: choice.rawValue), choice)
    XCTAssertEqual(choice.rawValue, "custom:9:768")  // legacy key format keeps decoding
    XCTAssertEqual(choice.keyLabels, ["⇧", "⌘", "V"])
    XCTAssertEqual(choice.keyCombo, combo)
    XCTAssertEqual(choice.inputCombo, .key(combo))
    XCTAssertNil(ShortcutChoice(rawValue: "custom:not-a-combo"))
  }

  func testMouseShortcutRoundTripsThroughRawValue() {
    let combo = MouseButtonCombo(buttonNumber: 3, carbonModifiers: 0)  // side button M4
    let choice = ShortcutChoice.custom(.mouse(combo))
    XCTAssertEqual(ShortcutChoice(rawValue: choice.rawValue), choice)
    XCTAssertEqual(choice.rawValue, "custom:mouse:3:0")
    XCTAssertEqual(choice.keyLabels, ["M4"])
    XCTAssertNil(choice.keyCombo)  // no Carbon hotkey for a mouse trigger
    XCTAssertEqual(choice.inputCombo, .mouse(combo))
  }

  func testInputComboStorageDistinguishesKeyAndMouse() {
    let key = InputCombo.key(KeyCombo(keyCode: 15, carbonModifiers: UInt32(controlKey)))
    let mouse = InputCombo.mouse(MouseButtonCombo(buttonNumber: 2, carbonModifiers: UInt32(cmdKey)))
    XCTAssertEqual(InputCombo(storageString: key.storageString), key)
    XCTAssertEqual(InputCombo(storageString: mouse.storageString), mouse)
    XCTAssertEqual(mouse.keyLabels, ["⌘", "M3"])
    XCTAssertNil(InputCombo(storageString: "mouse:x:0"))
    XCTAssertNil(InputCombo(storageString: ""))
  }

  func testMouseButtonsRequireMiddleOrSideButton() {
    XCTAssertFalse(MouseButtonCombo(buttonNumber: 0, carbonModifiers: 0).isUsableAsGlobalShortcut)
    XCTAssertFalse(
      MouseButtonCombo(buttonNumber: 1, carbonModifiers: UInt32(cmdKey)).isUsableAsGlobalShortcut)
    XCTAssertTrue(MouseButtonCombo(buttonNumber: 2, carbonModifiers: 0).isUsableAsGlobalShortcut)
    XCTAssertTrue(MouseButtonCombo(buttonNumber: 4, carbonModifiers: 0).isUsableAsGlobalShortcut)
  }

  func testKeyComboStorageStringRoundTrips() {
    let combo = KeyCombo(keyCode: 49, carbonModifiers: UInt32(controlKey | optionKey))
    XCTAssertEqual(KeyCombo(storageString: combo.storageString), combo)
    XCTAssertNil(KeyCombo(storageString: ""))
    XCTAssertNil(KeyCombo(storageString: "12"))
    XCTAssertNil(KeyCombo(storageString: "a:b"))
  }

  func testGlobalShortcutRequiresModifierExceptFunctionRow() {
    XCTAssertFalse(KeyCombo(keyCode: 9, carbonModifiers: 0).isUsableAsGlobalShortcut)
    XCTAssertTrue(KeyCombo(keyCode: 9, carbonModifiers: UInt32(cmdKey)).isUsableAsGlobalShortcut)
    XCTAssertTrue(KeyCombo(keyCode: 96, carbonModifiers: 0).isUsableAsGlobalShortcut)  // F5
    XCTAssertFalse(KeyCombo(keyCode: 49, carbonModifiers: 0).isUsableAsGlobalShortcut)  // bare Space
  }

  func testPresetCombosMatchTheirLabels() {
    XCTAssertNil(ShortcutChoice.functionKey.keyCombo)
    XCTAssertEqual(
      ShortcutChoice.controlOptionSpace.keyCombo,
      KeyCombo(keyCode: UInt16(kVK_Space), carbonModifiers: UInt32(controlKey | optionKey)))
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
