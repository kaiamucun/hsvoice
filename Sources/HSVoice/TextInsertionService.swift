import AppKit
import ApplicationServices
import Foundation

@MainActor
final class TextInsertionService {
  private var lastExternalTarget: AppTarget?
  private var activationObserver: NSObjectProtocol?

  private struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
      items = (pasteboard.pasteboardItems ?? []).map { item in
        Dictionary(
          uniqueKeysWithValues: item.types.compactMap { type in
            item.data(forType: type).map { (type, $0) }
          })
      }
    }

    func restore(to pasteboard: NSPasteboard) {
      pasteboard.clearContents()
      guard !items.isEmpty else { return }
      let pasteboardItems = items.map { values -> NSPasteboardItem in
        let item = NSPasteboardItem()
        for (type, data) in values {
          item.setData(data, forType: type)
        }
        return item
      }
      pasteboard.writeObjects(pasteboardItems)
    }
  }

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

  func insert(_ text: String, into target: AppTarget?) async -> TextInsertionOutcome {
    let pasteboard = NSPasteboard.general
    let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    let insertionChangeCount = pasteboard.changeCount

    guard AXIsProcessTrusted(), let target else {
      return .copiedOnly
    }

    guard await activate(target) else { return .copiedOnly }
    try? await Task.sleep(nanoseconds: 40_000_000)

    guard postCommandKey(virtualKey: 9) else { return .copiedOnly }

    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 900_000_000)
      if pasteboard.changeCount == insertionChangeCount {
        snapshot.restore(to: pasteboard)
      }
    }
    return .pasted
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

  private func activate(_ target: AppTarget) async -> Bool {
    guard !target.application.isTerminated,
      target.application.activate(options: [])
    else { return false }

    for _ in 0..<8 {
      if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
        return true
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
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
