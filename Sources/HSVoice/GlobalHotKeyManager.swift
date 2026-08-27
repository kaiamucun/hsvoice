import AppKit
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

  var hotKeyID = EventHotKeyID()
  let idStatus = GetEventParameter(
    event,
    EventParamName(kEventParamDirectObject),
    EventParamType(typeEventHotKeyID),
    nil,
    MemoryLayout<EventHotKeyID>.size,
    nil,
    &hotKeyID
  )
  guard idStatus == noErr else { return OSStatus(eventNotHandledErr) }

  switch (GetEventKind(event), hotKeyID.id) {
  case (UInt32(kEventHotKeyPressed), GlobalHotKeyManager.dictationHotKeyID):
    DispatchQueue.main.async { manager.receivePressed() }
    return noErr
  case (UInt32(kEventHotKeyReleased), GlobalHotKeyManager.dictationHotKeyID):
    DispatchQueue.main.async { manager.receiveReleased() }
    return noErr
  case (UInt32(kEventHotKeyPressed), GlobalHotKeyManager.repeatHotKeyID):
    DispatchQueue.main.async { manager.receiveRepeatPressed() }
    return noErr
  case (UInt32(kEventHotKeyReleased), GlobalHotKeyManager.repeatHotKeyID):
    // A repeat trigger only acts on the press; the release is still consumed
    // so it does not leak to the frontmost app.
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

  // Only a delivered *fn* event is evidence that the fast poll can be retired.
  // A shift press would prove the tap is alive in general, but not that it sees
  // the one key the shortcut depends on. The tap callback already runs on the
  // main run loop, so this read is safe and keeps the check from costing a
  // dispatch on every keystroke once it is confirmed.
  if !manager.functionTapIsConfirmed {
    let generation = manager.currentRegistrationGeneration
    DispatchQueue.main.async { manager.noteFunctionTapDelivered(generation: generation) }
  }

  DispatchQueue.main.async { manager.processFunctionFlags(event.flags) }

  // HS Voice owns a standalone fn press so macOS does not also invoke the Globe-key action.
  return nil
}

private func handleMouseButtonEvent(
  _ proxy: CGEventTapProxy,
  _ type: CGEventType,
  _ event: CGEvent,
  _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userData else { return Unmanaged.passUnretained(event) }
  let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    DispatchQueue.main.async { manager.reenableMouseTap() }
    return Unmanaged.passUnretained(event)
  }

  guard type == .otherMouseDown || type == .otherMouseUp else {
    return Unmanaged.passUnretained(event)
  }

  // The consume decision must be synchronous, so the match runs right here on
  // the main run loop (where this tap is scheduled); only the resulting state
  // transitions are dispatched, keeping the callback as cheap as the fn tap's.
  let consumed = manager.processMouseButtonEvent(
    isDown: type == .otherMouseDown,
    button: event.getIntegerValueField(.mouseEventButtonNumber),
    carbonModifiers: KeyCombo.carbonModifiers(from: event.flags)
  )
  return consumed ? nil : Unmanaged.passUnretained(event)
}

final class GlobalHotKeyManager {
  var onPressed: (() -> Void)?
  var onReleased: (() -> Void)?
  /// Fired on the press of the separately registered "re-insert the last
  /// dictation" shortcut.
  var onRepeatPressed: (() -> Void)?

  /// Carbon hot-key IDs (`EventHotKeyID.id`) telling the shared event handler
  /// which registration fired.
  fileprivate static let dictationHotKeyID: UInt32 = 1
  fileprivate static let repeatHotKeyID: UInt32 = 2

  private var hotKeyRef: EventHotKeyRef?
  private var repeatHotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var dictationMouseCombo: MouseButtonCombo?
  private var repeatMouseCombo: MouseButtonCombo?
  private var mouseEventTap: CFMachPort?
  private var mouseEventSource: CFRunLoopSource?
  private var mouseFallbackMonitors: [Any] = []
  /// Buttons whose *down* this manager consumed, so the matching *up* is also
  /// consumed (an app must never receive an orphan button-up), and releases
  /// stay permissive about modifiers the way fn releases are.
  private var dictationMouseButtonIsDown = false
  private var repeatMouseButtonIsDown = false
  private var functionEventTap: CFMachPort?
  private var functionEventSource: CFRunLoopSource?
  private var functionPollingTimer: Timer?
  private var functionKeyState = FunctionKeyStateTracker()
  private var functionTapConfirmed = false
  private var registrationGeneration = 0
  private var isPressed = false

  deinit {
    unregister()
  }

  @discardableResult
  func register(_ shortcut: ShortcutChoice) -> Bool {
    unregisterDictationShortcut()

    switch shortcut {
    case .functionKey:
      return registerFunctionKey()
    case .custom(.mouse(let combo)):
      guard combo.isUsableAsGlobalShortcut else { return false }
      dictationMouseCombo = combo
      return ensureMouseWatcher()
    default:
      guard let combo = shortcut.keyCombo, combo.isUsableAsGlobalShortcut else { return false }
      guard let ref = registerCombo(combo, identifier: Self.dictationHotKeyID) else { return false }
      hotKeyRef = ref
      return true
    }
  }

  /// Registers the independent "re-insert the last dictation" shortcut.
  /// It shares the Carbon event handler with the dictation shortcut but has
  /// its own registration, so either can change without touching the other.
  @discardableResult
  func registerRepeatShortcut(_ input: InputCombo) -> Bool {
    unregisterRepeatShortcut()
    guard input.isUsableAsGlobalShortcut else { return false }
    switch input {
    case .key(let combo):
      guard let ref = registerCombo(combo, identifier: Self.repeatHotKeyID) else { return false }
      repeatHotKeyRef = ref
      return true
    case .mouse(let combo):
      repeatMouseCombo = combo
      return ensureMouseWatcher()
    }
  }

  func unregisterRepeatShortcut() {
    if let repeatHotKeyRef {
      UnregisterEventHotKey(repeatHotKeyRef)
      self.repeatHotKeyRef = nil
    }
    repeatMouseCombo = nil
    repeatMouseButtonIsDown = false
    removeEventHandlerIfUnused()
    tearDownMouseWatcherIfUnused()
  }

  /// Both registrations are torn down while the settings recorder captures a
  /// combination, so the keys being tried out cannot trigger the app itself.
  /// The caller re-registers both when capture ends.
  func suspendRegistrations() {
    unregisterDictationShortcut()
    unregisterRepeatShortcut()
  }

  private func registerCombo(_ combo: KeyCombo, identifier: UInt32) -> EventHotKeyRef? {
    guard ensureEventHandlerInstalled() else { return nil }

    let hotKeyID = EventHotKeyID(signature: OSType(0x4853_5643), id: identifier)  // HSVC
    var ref: EventHotKeyRef?
    let registerStatus = RegisterEventHotKey(
      UInt32(combo.keyCode),
      combo.carbonModifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &ref
    )
    guard registerStatus == noErr, let ref else {
      removeEventHandlerIfUnused()
      return nil
    }
    return ref
  }

  private func ensureEventHandlerInstalled() -> Bool {
    guard eventHandlerRef == nil else { return true }

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
    return installStatus == noErr
  }

  private func removeEventHandlerIfUnused() {
    guard hotKeyRef == nil, repeatHotKeyRef == nil, let eventHandlerRef else { return }
    RemoveEventHandler(eventHandlerRef)
    self.eventHandlerRef = nil
  }

  func unregister() {
    unregisterDictationShortcut()
    unregisterRepeatShortcut()
  }

  private func unregisterDictationShortcut() {
    isPressed = false
    dictationMouseCombo = nil
    dictationMouseButtonIsDown = false
    tearDownMouseWatcherIfUnused()
    functionTapConfirmed = false
    registrationGeneration &+= 1
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
    removeEventHandlerIfUnused()
  }

  /// One shared watcher serves both mouse-triggered shortcuts. Preferred form
  /// is a CGEvent tap (consumes the click so the app under the cursor never
  /// sees it — a side button won't also navigate the browser); without the
  /// Accessibility permission the tap cannot be created and NSEvent global +
  /// local monitors take over, which trigger fine but cannot consume.
  private func ensureMouseWatcher() -> Bool {
    guard mouseEventTap == nil, mouseFallbackMonitors.isEmpty else { return true }

    let eventMask =
      (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
      | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
    if let eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: handleMouseButtonEvent,
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) {
      guard let eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
      else {
        // Never abandon an active tap: unserviced it would stall button
        // delivery system-wide until macOS disables it.
        CFMachPortInvalidate(eventTap)
        installMouseFallbackMonitors()
        return true
      }
      mouseEventTap = eventTap
      mouseEventSource = eventSource
      CFRunLoopAddSource(CFRunLoopGetMain(), eventSource, .commonModes)
      CGEvent.tapEnable(tap: eventTap, enable: true)
      return true
    }

    installMouseFallbackMonitors()
    return true
  }

  /// Called after a permissions refresh: an Accessibility grant given while
  /// the NSEvent fallback is in use lets the consuming tap be created now, so
  /// mouse triggers stop leaking their clicks to the app under the cursor.
  func upgradeMouseWatcherIfPossible() {
    guard mouseEventTap == nil, !mouseFallbackMonitors.isEmpty else { return }
    guard dictationMouseCombo != nil || repeatMouseCombo != nil else { return }
    for monitor in mouseFallbackMonitors {
      NSEvent.removeMonitor(monitor)
    }
    mouseFallbackMonitors = []
    _ = ensureMouseWatcher()
  }

  private func installMouseFallbackMonitors() {
    if let global = NSEvent.addGlobalMonitorForEvents(
      matching: [.otherMouseDown, .otherMouseUp],
      handler: { [weak self] event in
        _ = self?.processMouseButtonEvent(
          isDown: event.type == .otherMouseDown,
          button: Int64(event.buttonNumber),
          carbonModifiers: KeyCombo.carbonModifiers(from: event.modifierFlags)
        )
      })
    {
      mouseFallbackMonitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(
      matching: [.otherMouseDown, .otherMouseUp],
      handler: { [weak self] event in
        let consumed =
          self?.processMouseButtonEvent(
            isDown: event.type == .otherMouseDown,
            button: Int64(event.buttonNumber),
            carbonModifiers: KeyCombo.carbonModifiers(from: event.modifierFlags)
          ) ?? false
        return consumed ? nil : event
      })
    {
      mouseFallbackMonitors.append(local)
    }
  }

  private func tearDownMouseWatcherIfUnused() {
    guard dictationMouseCombo == nil, repeatMouseCombo == nil else { return }
    if let mouseEventSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), mouseEventSource, .commonModes)
      self.mouseEventSource = nil
    }
    if let mouseEventTap {
      CGEvent.tapEnable(tap: mouseEventTap, enable: false)
      CFMachPortInvalidate(mouseEventTap)
      self.mouseEventTap = nil
    }
    for monitor in mouseFallbackMonitors {
      NSEvent.removeMonitor(monitor)
    }
    mouseFallbackMonitors = []
  }

  fileprivate func reenableMouseTap() {
    guard let mouseEventTap else { return }
    CGEvent.tapEnable(tap: mouseEventTap, enable: true)
    // The disabled interval may have swallowed a button release. Reset the
    // down-flags — and end a hold-mode recording — so no state can stick.
    if dictationMouseButtonIsDown {
      dictationMouseButtonIsDown = false
      receiveReleased()
    }
    repeatMouseButtonIsDown = false
  }

  /// Matches a button event against both registrations. Returns whether the
  /// event was claimed (the tap then consumes it). A press requires the exact
  /// recorded modifiers; the matching release is permissive about modifiers —
  /// like fn releases — so letting go of the modifier first still ends a
  /// hold-to-talk recording.
  fileprivate func processMouseButtonEvent(
    isDown: Bool, button: Int64, carbonModifiers: UInt32
  ) -> Bool {
    if let combo = dictationMouseCombo, button == Int64(combo.buttonNumber) {
      if isDown, carbonModifiers == combo.carbonModifiers {
        dictationMouseButtonIsDown = true
        DispatchQueue.main.async { self.receivePressed() }
        return true
      }
      if !isDown, dictationMouseButtonIsDown {
        dictationMouseButtonIsDown = false
        DispatchQueue.main.async { self.receiveReleased() }
        return true
      }
    }

    if let combo = repeatMouseCombo, button == Int64(combo.buttonNumber) {
      if isDown, carbonModifiers == combo.carbonModifiers {
        repeatMouseButtonIsDown = true
        DispatchQueue.main.async { self.receiveRepeatPressed() }
        return true
      }
      if !isDown, repeatMouseButtonIsDown {
        repeatMouseButtonIsDown = false
        return true
      }
    }

    return false
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

  fileprivate func receiveRepeatPressed() {
    onRepeatPressed?()
  }

  fileprivate func reenableFunctionKeyTap() {
    guard let functionEventTap else { return }
    CGEvent.tapEnable(tap: functionEventTap, enable: true)
    // The tap just proved it can stop delivering, so go back to the fast poll
    // until it demonstrates otherwise.
    functionTapConfirmed = false
    installFunctionPollingTimer(interval: Timing.functionKeyPollInterval)
  }

  fileprivate var functionTapIsConfirmed: Bool { functionTapConfirmed }

  fileprivate var currentRegistrationGeneration: Int { registrationGeneration }

  /// Called the first time the event tap actually delivers a modifier event.
  ///
  /// The tap reports fn presses with no delay, so once it is known to work the
  /// timer is only a repair mechanism for a transition the tap missed. Dropping it
  /// from 60 Hz to 10 Hz removes almost all of HS Voice's idle CPU wakeups, which
  /// matters for an app that sits in the menu bar all day.
  fileprivate func noteFunctionTapDelivered(generation: Int) {
    // The confirmation is dispatched asynchronously, so one enqueued by a tap that
    // has since been torn down and re-registered must not vouch for its unproven
    // replacement. `register` runs again on every activation and settings change.
    guard generation == registrationGeneration else { return }
    guard functionEventTap != nil, !functionTapConfirmed else { return }
    functionTapConfirmed = true
    installFunctionPollingTimer(interval: Timing.functionKeyWatchdogInterval)
  }

  private func installFunctionPollingTimer(interval: TimeInterval) {
    functionPollingTimer?.invalidate()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      self?.pollFunctionKeyState()
    }
    functionPollingTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func processFunctionFlags(_ flags: CGEventFlags) {
    processFunctionKeyState(flags.contains(.maskSecondaryFn))
  }

  func processFunctionKeyState(_ isDown: Bool) {
    // macOS synthesizes the fn modifier while navigation keys are held — arrows,
    // Home/End, Page Up/Down, forward-delete, the function row — and on recent
    // macOS that synthesis also shows up as keyCode-63 events and as HID key
    // state for fn itself. A *press* therefore only counts while none of those
    // fn-synthesizing keys is down. Only that specific set is checked: scanning
    // every keycode also vetoed on phantom "stuck" states (a lost key-up from a
    // synthetic event, a flaky HID report) and silently disabled fn entirely.
    // Releases stay permissive so a real recording can always end.
    if isDown, !functionKeyState.isDown, anyFnSynthesizerKeyIsDown() { return }
    guard let transition = functionKeyState.update(isDown: isDown) else { return }
    switch transition {
    case .pressed:
      receivePressed()
    case .released:
      receiveReleased()
    }
  }

  private func registerFunctionKey() -> Bool {
    // Reading the HID key state does not depend on successful creation of an
    // Accessibility-backed event tap. Polling is therefore the reliable primary path;
    // the tap below is only an optional low-latency path that suppresses Globe actions.
    functionKeyState = FunctionKeyStateTracker(isDown: physicalFunctionKeyIsDown())
    functionTapConfirmed = false
    installFunctionPollingTimer(interval: Timing.functionKeyPollInterval)

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
    let keyIsDown = physicalFunctionKeyIsDown()

    if functionKeyState.isDown {
      // Repairing a stuck "pressed" state may also consult the fn *flag*: a
      // release is only reported once every fn-related signal is gone.
      let flagIsDown = CGEventSource.flagsState(.hidSystemState).contains(.maskSecondaryFn)
      if !keyIsDown && !flagIsDown {
        processFunctionKeyState(false)
      }
    } else if keyIsDown {
      processFunctionKeyState(true)
    }
  }

  /// The fn key's own HID state. Note this is *not* proof the physical key is
  /// held: navigation keys make macOS synthesize the fn layer, and that shows up
  /// here too. `processFunctionKeyState` adds the no-other-key-down check that
  /// turns this signal into an actual press.
  private func physicalFunctionKeyIsDown() -> Bool {
    CGEventSource.keyState(.hidSystemState, key: CGKeyCode(kVK_Function))
  }

  /// The keys whose press makes macOS synthesize the fn layer. Ordinary keys
  /// cannot fake the fn signal, so they are deliberately NOT scanned.
  private static let fnSynthesizerKeyCodes: [CGKeyCode] = [
    123, 124, 125, 126,  // arrows
    115, 119, 116, 121, 117, 114,  // Home, End, Page Up/Down, forward delete, Help
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,  // F1–F12
    105, 107, 113, 106, 64, 79, 80,  // F13–F19
  ]

  private func anyFnSynthesizerKeyIsDown() -> Bool {
    Self.fnSynthesizerKeyCodes.contains { CGEventSource.keyState(.hidSystemState, key: $0) }
  }

  /// One-line snapshot of every input the fn decision uses, for the
  /// diagnostics report. A "stuck" value here explains a dead or firing fn
  /// instantly, without guessing.
  var fnDebugSnapshot: String {
    let downSynthesizers = Self.fnSynthesizerKeyCodes.filter {
      CGEventSource.keyState(.hidSystemState, key: $0)
    }
    return "fnKeyState=\(physicalFunctionKeyIsDown())"
      + " fnFlag=\(CGEventSource.flagsState(.hidSystemState).contains(.maskSecondaryFn))"
      + " trackerDown=\(functionKeyState.isDown)"
      + " pressed=\(isPressed)"
      + " tapActive=\(functionEventTap != nil)"
      + " tapConfirmed=\(functionTapConfirmed)"
      + " synthKeysDown=\(downSynthesizers)"
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
