import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class OverlayWindowController {
  static let shared = OverlayWindowController()

  private let panel: NSPanel
  private var screenChangeObserver: NSObjectProtocol?

  private init() {
    panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 64),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentView = NSHostingView(rootView: RecordingOverlayView(model: .shared))
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false
    panel.setAccessibilityLabel("HS Voice 状態")

    screenChangeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.positionPanel()
      }
    }
  }

  func show() {
    positionPanel()
    panel.orderFrontRegardless()
  }

  private func positionPanel() {
    guard let visibleFrame = Self.activeWorkScreen()?.visibleFrame else { return }
    let origin = NSPoint(
      x: visibleFrame.midX - panel.frame.width / 2,
      y: visibleFrame.minY + 4
    )
    panel.setFrameOrigin(origin)
  }

  /// The screen the user is actually working on.
  ///
  /// With several displays the indicator must appear where dictation will land,
  /// not on whichever display owns the menu bar. The focused window of the
  /// frontmost application is the best signal; the mouse pointer is the
  /// fallback when Accessibility cannot be consulted, and the menu-bar screen
  /// is the last resort.
  private static func activeWorkScreen() -> NSScreen? {
    if let windowFrame = focusedWindowFrame() {
      let screen = NSScreen.screens.max { first, second in
        intersectionArea(first.frame, windowFrame) < intersectionArea(second.frame, windowFrame)
      }
      if let screen, intersectionArea(screen.frame, windowFrame) > 0 {
        return screen
      }
    }

    let mouseLocation = NSEvent.mouseLocation
    let mouseScreen = NSScreen.screens.first { screen in
      NSMouseInRect(mouseLocation, screen.frame, false)
    }
    if let mouseScreen {
      return mouseScreen
    }

    return NSScreen.screens.first ?? NSScreen.main
  }

  private static func intersectionArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
    let r = a.intersection(b)
    return r.isNull ? 0 : r.width * r.height
  }

  /// Frame of the frontmost application's focused window, in Cocoa
  /// (bottom-left origin) screen coordinates. Returns nil without the
  /// Accessibility permission or when nothing has focus.
  private static func focusedWindowFrame() -> NSRect? {
    guard AXIsProcessTrusted(),
      let application = NSWorkspace.shared.frontmostApplication
    else { return nil }

    let element = AXUIElementCreateApplication(application.processIdentifier)
    var focused: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focused)
        == .success
    else { return nil }
    let window = focused as! AXUIElement

    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        == .success,
      AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
    else { return nil }

    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
      AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
      size.width > 0, size.height > 0
    else { return nil }

    // AX coordinates are top-left based on the primary display; Cocoa screen
    // coordinates are bottom-left based.
    guard let primary = NSScreen.screens.first else { return nil }
    let cocoaY = primary.frame.maxY - position.y - size.height
    return NSRect(x: position.x, y: cocoaY, width: size.width, height: size.height)
  }
}

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
  static let shared = OnboardingWindowController()

  private var window: NSWindow?
  var isVisible: Bool { window?.isVisible == true }

  func show() {
    let window = window ?? makeWindow()
    self.window = window
    NSApp.activate(ignoringOtherApps: true)
    window.center()
    window.makeKeyAndOrderFront(nil)
  }

  func close() {
    window?.close()
  }

  func windowWillClose(_ notification: Notification) {
    window = nil
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "HS Voiceへようこそ"
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentView = NSHostingView(rootView: OnboardingView(model: .shared))
    return window
  }
}

@MainActor
final class HistoryWindowController: NSObject, NSWindowDelegate {
  static let shared = HistoryWindowController()

  private var window: NSWindow?
  var isVisible: Bool { window?.isVisible == true }

  func show() {
    let window = window ?? makeWindow()
    self.window = window
    NSApp.activate(ignoringOtherApps: true)
    window.center()
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    window = nil
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "HS Voice 履歴"
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentView = NSHostingView(rootView: HistoryView(model: .shared))
    return window
  }
}
