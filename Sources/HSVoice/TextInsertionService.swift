import AppKit
import ApplicationServices
import Foundation

private func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
  UInt64(max(0, seconds) * 1_000_000_000)
}

@MainActor
final class TextInsertionService {
  private var lastExternalTarget: AppTarget?
  private var activationObserver: NSObjectProtocol?

  /// UTF-16 units per synthesized keyboard event. `CGEvent` only carries about
  /// 20 units reliably, so longer transcripts are typed in chunks.
  private static let typingChunkLength = 20

  init() {
    rememberIfEligible(NSWorkspace.shared.frontmostApplication)
    activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else { return }
      Task { @MainActor [weak self] in
        self?.rememberIfEligible(application)
      }
    }
  }

  deinit {
    if let activationObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
    }
  }

  func currentTarget() -> AppTarget? {
    if let application = NSWorkspace.shared.frontmostApplication,
      isEligible(application)
    {
      let target = AppTarget(application: application)
      lastExternalTarget = target
      return target
    }

    guard let lastExternalTarget, !lastExternalTarget.application.isTerminated else {
      self.lastExternalTarget = nil
      return nil
    }
    return lastExternalTarget
  }

  /// Inserts text by synthesizing Unicode keystrokes directly into the target
  /// application. The clipboard is never touched on the success path — it is
  /// only written as a deliberate fallback when insertion cannot happen, so
  /// the user still has the transcript somewhere.
  func insert(_ text: String, into target: AppTarget?) async -> TextInsertionOutcome {
    guard let target else {
      return copyToPasteboard(text, as: .copiedOnly)
    }
    guard AXIsProcessTrusted() else {
      // The most common cause after a rebuild: the Accessibility toggle still
      // shows ON but the stale (ad-hoc-signed) grant no longer applies.
      return copyToPasteboard(text, as: .copiedNoAccessibility)
    }

    // HS Voice is a menu-bar accessory and never takes focus, so the target is
    // almost always still frontmost. Skipping the activation round-trip in that
    // common case removes the last avoidable delay between speaking and seeing
    // the text appear.
    let neededActivation: Bool
    if isFrontmost(target) {
      neededActivation = false
    } else {
      guard await activate(target) else {
        return copyToPasteboard(text, as: .copiedOnly)
      }
      neededActivation = true
    }

    let settleDelay =
      neededActivation ? Timing.insertionSettleDelayAfterActivation : Timing.insertionSettleDelay
    try? await Task.sleep(nanoseconds: nanoseconds(settleDelay))

    guard await typeUnicode(text) else {
      return copyToPasteboard(text, as: .copiedOnly)
    }
    return .inserted
  }

  func undo(in target: AppTarget?) -> Bool {
    guard AXIsProcessTrusted(), let target, !target.application.isTerminated else {
      return false
    }
    guard
      NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
    else {
      return false
    }
    return postCommandKey(virtualKey: 6)
  }

  private func copyToPasteboard(
    _ text: String, as outcome: TextInsertionOutcome
  ) -> TextInsertionOutcome {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    return outcome
  }

  /// Types `text` as synthesized keyboard events carrying Unicode payloads.
  ///
  /// Chunks never split a surrogate pair, the events carry explicitly empty
  /// modifier flags (so a still-held shortcut modifier cannot contaminate the
  /// text), and a short pause between chunks keeps slow event queues — Electron
  /// apps, remote desktops — from dropping characters.
  private func typeUnicode(_ text: String) async -> Bool {
    let units = Array(text.utf16)
    guard !units.isEmpty else { return true }

    var index = 0
    while index < units.count {
      var end = min(index + Self.typingChunkLength, units.count)
      if end < units.count, UTF16.isLeadSurrogate(units[end - 1]) {
        end -= 1
      }

      var chunk = Array(units[index..<end])
      guard
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
      else { return false }
      keyDown.flags = []
      keyUp.flags = []
      keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
      keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)

      index = end
      if index < units.count {
        try? await Task.sleep(nanoseconds: nanoseconds(Timing.insertionChunkInterval))
      }
    }
    return true
  }

  private func rememberIfEligible(_ application: NSRunningApplication?) {
    guard let application, isEligible(application) else { return }
    lastExternalTarget = AppTarget(application: application)
  }

  private func isEligible(_ application: NSRunningApplication) -> Bool {
    application.processIdentifier != ProcessInfo.processInfo.processIdentifier
      && !application.isTerminated
      && application.activationPolicy != .prohibited
      && application.bundleIdentifier != "com.apple.systempreferences"
  }

  private func isFrontmost(_ target: AppTarget) -> Bool {
    !target.application.isTerminated
      && NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
  }

  private func activate(_ target: AppTarget) async -> Bool {
    guard !target.application.isTerminated,
      target.application.activate(options: [])
    else { return false }

    // A finer poll returns as soon as the switch lands instead of rounding every
    // activation up to the next 50 ms tick. The total budget is
    // `Timing.activationTimeout`.
    let attempts = max(
      1,
      Int((Timing.activationTimeout / Timing.activationPollInterval).rounded())
    )
    for _ in 0..<attempts {
      if isFrontmost(target) { return true }
      try? await Task.sleep(nanoseconds: nanoseconds(Timing.activationPollInterval))
    }
    return false
  }

  private func postCommandKey(virtualKey: CGKeyCode) -> Bool {
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false)
    else { return false }
    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    return true
  }
}
