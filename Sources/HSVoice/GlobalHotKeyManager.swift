import Carbon.HIToolbox
import CoreGraphics
import Foundation

private func handleGlobalHotKey(
  _ nextHandler: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event, let userData else { return OSStatus(eventNotHandledErr) }
  let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

  switch GetEventKind(event) {
  case UInt32(kEventHotKeyPressed):
    DispatchQueue.main.async { manager.receivePressed() }
    return noErr
  case UInt32(kEventHotKeyReleased):
    DispatchQueue.main.async { manager.receiveReleased() }
    return noErr
  default:
    return OSStatus(eventNotHandledErr)
  }
}

private func handleFunctionKeyEvent(
  _ proxy: CGEventTapProxy,
  _ type: CGEventType,
  _ event: CGEvent,
  _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userData else { return Unmanaged.passUnretained(event) }
  let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    DispatchQueue.main.async { manager.reenableFunctionKeyTap() }
    return Unmanaged.passUnretained(event)
  }

  guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }
  let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
  guard keyCode == Int64(kVK_Function) else { return Unmanaged.passUnretained(event) }
  DispatchQueue.main.async { manager.processFunctionFlags(event.flags) }

  // HS Voice owns a standalone fn press so macOS does not also invoke the Globe-key action.
  return nil
}

final class GlobalHotKeyManager {
  var onPressed: (() -> Void)?
  var onReleased: (() -> Void)?

  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var functionEventTap: CFMachPort?
  private var functionEventSource: CFRunLoopSource?
  private var functionPollingTimer: Timer?
  private var functionKeyState = FunctionKeyStateTracker()
  private var isPressed = false

  deinit {
    unregister()
  }

  @discardableResult
  func register(_ shortcut: ShortcutChoice) -> Bool {
    unregister()

    if shortcut == .functionKey {
      return registerFunctionKey()
    }

    return registerSpaceShortcut(shortcut)
  }

  private func registerSpaceShortcut(_ shortcut: ShortcutChoice) -> Bool {

    var eventTypes = [
      EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]

    let installStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      handleGlobalHotKey,
      eventTypes.count,
      &eventTypes,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerRef
    )
    guard installStatus == noErr else { return false }

    let identifier = EventHotKeyID(signature: OSType(0x4853_5643), id: 1)  // HSVC
    let registerStatus = RegisterEventHotKey(
      UInt32(kVK_Space),
      modifiers(for: shortcut),
      identifier,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    guard registerStatus == noErr else {
      unregister()
      return false
    }
    return true
  }

  func unregister() {
    isPressed = false
    functionPollingTimer?.invalidate()
    functionPollingTimer = nil
    functionKeyState = FunctionKeyStateTracker()
    if let functionEventSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), functionEventSource, .commonModes)
      self.functionEventSource = nil
    }
    if let functionEventTap {
      CGEvent.tapEnable(tap: functionEventTap, enable: false)
      CFMachPortInvalidate(functionEventTap)
      self.functionEventTap = nil
    }
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
  }

  fileprivate func receivePressed() {
    guard !isPressed else { return }
    isPressed = true
    onPressed?()
  }

  fileprivate func receiveReleased() {
    guard isPressed else { return }
    isPressed = false
    onReleased?()
  }

  fileprivate func reenableFunctionKeyTap() {
    guard let functionEventTap else { return }
    CGEvent.tapEnable(tap: functionEventTap, enable: true)
  }

  func processFunctionFlags(_ flags: CGEventFlags) {
    processFunctionKeyState(flags.contains(.maskSecondaryFn))
  }

  func processFunctionKeyState(_ isDown: Bool) {
    guard let transition = functionKeyState.update(isDown: isDown) else { return }
    switch transition {
    case .pressed:
      receivePressed()
    case .released:
      receiveReleased()
    }
  }

  private func registerFunctionKey() -> Bool {
    // Reading the HID modifier state does not depend on successful creation of an
    // Accessibility-backed event tap. Polling is therefore the reliable primary path;
    // the tap below is only an optional low-latency path that suppresses Globe actions.
    functionKeyState = FunctionKeyStateTracker(isDown: physicalFunctionKeyIsDown())
    let pollingTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      self?.pollFunctionKeyState()
    }
    functionPollingTimer = pollingTimer
    RunLoop.main.add(pollingTimer, forMode: .common)

    let eventMask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: handleFunctionKeyEvent,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      return true
    }

    guard let eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
      CFMachPortInvalidate(eventTap)
      return true
    }

    functionEventTap = eventTap
    functionEventSource = eventSource
    CFRunLoopAddSource(CFRunLoopGetMain(), eventSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    return true
  }

  private func pollFunctionKeyState() {
    processFunctionKeyState(physicalFunctionKeyIsDown())
  }

  private func physicalFunctionKeyIsDown() -> Bool {
    let state: CGEventSourceStateID = .hidSystemState
    return CGEventSource.flagsState(state).contains(.maskSecondaryFn)
      || CGEventSource.keyState(state, key: CGKeyCode(kVK_Function))
  }

  private func modifiers(for shortcut: ShortcutChoice) -> UInt32 {
    switch shortcut {
    case .functionKey:
      return 0
    case .optionSpace:
      return UInt32(optionKey)
    case .controlSpace:
      return UInt32(controlKey)
    case .commandShiftSpace:
      return UInt32(cmdKey | shiftKey)
    case .controlOptionSpace:
      return UInt32(controlKey | optionKey)
    }
  }
}

enum FunctionKeyTransition: Equatable {
  case pressed
  case released
}

struct FunctionKeyStateTracker {
  private(set) var isDown: Bool

  init(isDown: Bool = false) {
    self.isDown = isDown
  }

  mutating func update(isDown nextIsDown: Bool) -> FunctionKeyTransition? {
    guard nextIsDown != isDown else { return nil }
    isDown = nextIsDown
    return nextIsDown ? .pressed : .released
  }
}
