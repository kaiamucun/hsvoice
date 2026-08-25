import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
  static let shared = OverlayWindowController()

  private let panel: NSPanel
  private var screenChangeObserver: NSObjectProtocol?

  private init() {
    panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 154),
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
    // An accessory app has no key document window, so NSScreen.main can follow the pointer and
    // place the persistent indicator on an unexpected display. The first screen owns the menu bar.
    let screen = NSScreen.screens.first ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else { return }
    let origin = NSPoint(
      x: visibleFrame.midX - panel.frame.width / 2,
      y: visibleFrame.minY + 4
    )
    panel.setFrameOrigin(origin)
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
