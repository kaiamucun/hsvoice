import Carbon.HIToolbox
import CoreGraphics
import XCTest

@testable import HSVoice

final class ShortcutChoiceTests: XCTestCase {
  func testShortcutChoicesIncludeBareModifierKeysAndUniqueFallbacks() {
    let shortcuts = ShortcutChoice.presets
    XCTAssertEqual(ShortcutChoice.functionKey.keyLabels, ["fn"])
    XCTAssertEqual(ShortcutChoice.control.keyLabels, ["control"])
    XCTAssertEqual(Array(shortcuts.prefix(2)), [.functionKey, .control])
    XCTAssertTrue(shortcuts.dropFirst(2).allSatisfy { $0.keyLabels.last == "Space" })
    XCTAssertEqual(Set(shortcuts.map(\.displayName)).count, shortcuts.count)
  }

  func testControlKeyIsABareModifierTriggerWithoutACarbonCombo() {
    // Like fn, a bare control key has no Carbon hotkey and no recordable combo;
    // it is watched through the modifier-key path of GlobalHotKeyManager.
    XCTAssertNil(ShortcutChoice.control.keyCombo)
    XCTAssertNil(ShortcutChoice.control.inputCombo)
    XCTAssertTrue(ShortcutChoice.control.isBareModifierKey)
    XCTAssertTrue(ShortcutChoice.functionKey.isBareModifierKey)
    XCTAssertFalse(ShortcutChoice.controlSpace.isBareModifierKey)
    XCTAssertFalse(
      ShortcutChoice.custom(.mouse(MouseButtonCombo(buttonNumber: 2, carbonModifiers: 0)))
        .isBareModifierKey)
  }

  func testPresetRawValuesStayStableForStoredSettings() {
    // These strings live in UserDefaults of existing installs.
    XCTAssertEqual(ShortcutChoice(rawValue: "functionKey"), .functionKey)
    XCTAssertEqual(ShortcutChoice(rawValue: "controlKey"), .control)
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

  // MARK: control key (bare modifier) trigger

  func testControlTriggerHeldPastThresholdIsAPressThenARelease() {
    var tracker = ModifierKeyTriggerTracker()
    XCTAssertEqual(tracker.update(isDown: true), [])
    XCTAssertEqual(tracker.phase, .pending)
    XCTAssertEqual(tracker.holdThresholdElapsed(), [.pressed])
    XCTAssertEqual(tracker.phase, .active)
    XCTAssertEqual(tracker.update(isDown: false), [.released])
    XCTAssertEqual(tracker.phase, .idle)
  }

  func testControlTriggerQuickTapDeliversPressAndReleaseTogether() {
    // Toggle and auto modes need a tap to reach the app even though the hold
    // threshold never elapsed.
    var tracker = ModifierKeyTriggerTracker()
    _ = tracker.update(isDown: true)
    XCTAssertEqual(tracker.update(isDown: false), [.pressed, .released])
    XCTAssertEqual(tracker.phase, .idle)
    // A threshold timer that fires after the tap is stale and must do nothing.
    XCTAssertEqual(tracker.holdThresholdElapsed(), [])
  }

  func testControlTriggerIgnoresFastKeyCombinations() {
    // ⌃C typed at normal speed: the letter lands before the hold threshold.
    var tracker = ModifierKeyTriggerTracker()
    _ = tracker.update(isDown: true)
    XCTAssertEqual(tracker.otherKeyDown(), [])
    XCTAssertEqual(tracker.phase, .suppressed)
    XCTAssertEqual(tracker.holdThresholdElapsed(), [])
    XCTAssertEqual(tracker.otherKeyDown(), [])  // key auto-repeat
    XCTAssertEqual(tracker.update(isDown: false), [])
    XCTAssertEqual(tracker.phase, .idle)
  }

  func testControlTriggerCancelsARecordingWhenASlowCombinationFollows() {
    // control held long enough to start, then another key: the hold was the
    // start of a combination after all, so the recording is discarded and
    // nothing fires again until control is released.
    var tracker = ModifierKeyTriggerTracker()
    _ = tracker.update(isDown: true)
    XCTAssertEqual(tracker.holdThresholdElapsed(), [.pressed])
    XCTAssertEqual(tracker.otherKeyDown(), [.cancelled])
    XCTAssertEqual(tracker.phase, .suppressed)
    XCTAssertEqual(tracker.update(isDown: false), [])
    XCTAssertEqual(tracker.update(isDown: true), [])
    XCTAssertEqual(tracker.phase, .pending)
  }

  func testControlTriggerHeldDuringRegistrationNeverFiresOnItsRelease() {
    var tracker = ModifierKeyTriggerTracker(isDown: true)
    XCTAssertTrue(tracker.isKeyDown)
    XCTAssertEqual(tracker.holdThresholdElapsed(), [])
    XCTAssertEqual(tracker.update(isDown: false), [])
    XCTAssertEqual(tracker.phase, .idle)
  }

  func testControlTriggerSeesACombinationBeforeTheModifierItself() {
    // The letter's keyDown carries the control flag even when the control
    // press was not observed yet (poll not ticked, tap not delivering).
    var tracker = ModifierKeyTriggerTracker()
    XCTAssertEqual(tracker.otherKeyDown(), [])
    XCTAssertEqual(tracker.phase, .suppressed)
    XCTAssertEqual(tracker.update(isDown: true), [])  // the late "down" changes nothing
    XCTAssertEqual(tracker.phase, .suppressed)
    XCTAssertEqual(tracker.update(isDown: false), [])
    XCTAssertEqual(tracker.phase, .idle)
  }

  func testControlTriggerRepeatedStateReportsAreIdempotent() {
    var tracker = ModifierKeyTriggerTracker()
    XCTAssertEqual(tracker.update(isDown: false), [])
    _ = tracker.update(isDown: true)
    XCTAssertEqual(tracker.update(isDown: true), [])
    XCTAssertEqual(tracker.phase, .pending)
  }

  func testManagerDeliversControlTriggerTransitionsAndRecoversAfterCancel() {
    let manager = GlobalHotKeyManager()
    var log: [String] = []
    manager.onPressed = { log.append("pressed") }
    manager.onReleased = { log.append("released") }
    manager.onCancelled = { log.append("cancelled") }

    manager.processModifierKeyState(true)
    manager.fireModifierHoldThresholdForTesting()
    manager.processOtherKeyDownWhileModifierHeld()
    manager.processModifierKeyState(false)
    XCTAssertEqual(log, ["pressed", "cancelled"])

    // The cancel reset the pressed flag, so the next hold is a fresh press.
    manager.processModifierKeyState(true)
    manager.fireModifierHoldThresholdForTesting()
    manager.processModifierKeyState(false)
    XCTAssertEqual(log, ["pressed", "cancelled", "pressed", "released"])
  }

  func testManagerTreatsAQuickControlTapAsPressAndRelease() {
    let manager = GlobalHotKeyManager()
    var log: [String] = []
    manager.onPressed = { log.append("pressed") }
    manager.onReleased = { log.append("released") }
    manager.onCancelled = { log.append("cancelled") }

    manager.processModifierKeyState(true)
    manager.processModifierKeyState(false)
    XCTAssertEqual(log, ["pressed", "released"])
  }
}
