import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class OverlayWindowController {
  static let shared = OverlayWindowController()

  private let panel: NSPanel
  private var screenChangeObserver: NSObjectProtocol?
  private var repositionTimer: Timer?

  /// Display that most recently contained a text caret. `NSScreen` instances
  /// are recreated on configuration changes, so the stable display ID is stored
  /// instead of a screen object.
  private var lastCaretDisplayID: CGDirectDisplayID?

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

    installRepositionTimer()
  }

  func show() {
    positionPanel()
    panel.orderFrontRegardless()
  }

  /// The indicator follows the user across displays even while idle.
  ///
  /// There is no cross-application "focus moved" notification without building
  /// a per-app AXObserver web, so a slow poll re-evaluates the work screen and
  /// moves the panel when it changes. The panel only actually moves when the
  /// computed origin differs, so the steady state costs one focus lookup.
  private func installRepositionTimer() {
    let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.positionPanel()
      }
    }
    repositionTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func positionPanel() {
    guard let visibleFrame = activeWorkScreen()?.visibleFrame else { return }
    let origin = NSPoint(
      x: visibleFrame.midX - panel.frame.width / 2,
      y: visibleFrame.minY + 4
    )
    if abs(panel.frame.origin.x - origin.x) > 0.5 || abs(panel.frame.origin.y - origin.y) > 0.5 {
      panel.setFrameOrigin(origin)
    }
  }

  /// The screen the user is actually working on.
  ///
  /// Dictation lands at the text caret, so a live caret's display is the best
  /// possible signal. When the focused element exposes no caret (Finder, a
  /// button, many Electron apps), the frontmost window's screen and then the
  /// mouse pointer decide — the mouse is what actually follows a click onto
  /// another monitor. The display that last had a caret is only a late
  /// fallback: letting it outrank the mouse pinned the indicator to whichever
  /// monitor last showed a caret-exposing app, which read as "stuck on the
  /// main display".
  private func activeWorkScreen() -> NSScreen? {
    if let caretRect = Self.focusedCaretRect(),
      let screen = Self.screen(containing: NSPoint(x: caretRect.midX, y: caretRect.midY))
    {
      lastCaretDisplayID = screen.displayID
      return screen
    }

    if let windowFrame = Self.focusedWindowFrame() {
      let screen = NSScreen.screens.max { first, second in
        Self.intersectionArea(first.frame, windowFrame)
          < Self.intersectionArea(second.frame, windowFrame)
      }
      if let screen, Self.intersectionArea(screen.frame, windowFrame) > 0 {
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

    if let lastCaretDisplayID,
      let screen = NSScreen.screens.first(where: { $0.displayID == lastCaretDisplayID })
    {
      return screen
    }

    return NSScreen.screens.first ?? NSScreen.main
  }

  private static func screen(containing point: NSPoint) -> NSScreen? {
    NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
  }

  /// Global (Cocoa, bottom-left origin) rect of the text caret in the focused
  /// UI element, or nil without the Accessibility permission, without a focused
  /// element, or when the element does not expose caret geometry.
  /// System-wide AX entry point with a short messaging timeout, so an
  /// unresponsive application cannot stall the reposition poll (the default
  /// timeout is several seconds, and this query runs on the main thread).
  private static let systemWideElement: AXUIElement = {
    let element = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(element, 0.25)
    return element
  }()

  private static func focusedCaretRect() -> NSRect? {
    guard AXIsProcessTrusted() else { return nil }

    var focused: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        systemWideElement, kAXFocusedUIElementAttribute as CFString, &focused)
        == .success,
      let focused
    else { return nil }
    let element = focused as! AXUIElement
    AXUIElementSetMessagingTimeout(element, 0.25)

    var rangeValue: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
      let rangeValue
    else { return nil }

    var boundsValue: CFTypeRef?
    guard
      AXUIElementCopyParameterizedAttributeValue(
        element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue, &boundsValue)
        == .success,
      let boundsValue
    else { return nil }

    var rect = CGRect.zero
    guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
      rect != .zero
    else { return nil }

    // AX coordinates are top-left based on the primary display; Cocoa screen
    // coordinates are bottom-left based.
    guard let primary = NSScreen.screens.first else { return nil }
    let cocoaY = primary.frame.maxY - rect.origin.y - rect.height
    return NSRect(x: rect.origin.x, y: cocoaY, width: rect.width, height: rect.height)
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
    window.title = L.t("HS Voiceへようこそ", "Welcome to HS Voice", "欢迎使用HS Voice", "HS Voice에 오신 것을 환영합니다")
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
    window.title = L.t("HS Voice 履歴", "HS Voice History", "HS Voice 历史", "HS Voice 기록")
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.contentView = NSHostingView(rootView: HistoryView(model: .shared))
    return window
  }
}

extension NSScreen {
  fileprivate var displayID: CGDirectDisplayID? {
    (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
  }
}
