import AppKit
import SwiftUI

@main
struct HSVoiceApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel.shared

  var body: some Scene {
    Window("HS Voice", id: "settings") {
      PrimaryWindowView(model: model)
    }
    .defaultSize(width: 670, height: 540)
    .windowResizability(.contentMinSize)
    .commands {
      HSVoiceCommands()
    }

    MenuBarExtra {
      MenuBarView(model: model)
    } label: {
      Label("HS Voice", systemImage: model.menuBarSymbol)
    }
    .menuBarExtraStyle(.window)
  }
}

private struct PrimaryWindowView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  @ViewBuilder
  var body: some View {
    if settings.completedOnboarding {
      SettingsView(model: model)
    } else {
      OnboardingView(model: model)
    }
  }
}

private struct HSVoiceCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(replacing: .appSettings) {
      Button(L.t("設定…", "Settings…", "设置…", "설정…")) {
        openWindow(id: "settings")
      }
      .keyboardShortcut(",", modifiers: .command)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    AppModel.shared.startServices()

    if launchedAsLoginItem {
      DispatchQueue.main.async { [weak self] in
        self?.hidePrimaryWindow()
      }
    }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    AppModel.shared.refreshPermissions()
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppModel.shared.cancelListening()
  }

  private var launchedAsLoginItem: Bool {
    NSAppleEventManager.shared().currentAppleEvent?
      .paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem))?
      .booleanValue ?? false
  }

  private func hidePrimaryWindow() {
    for window in NSApp.windows where window.title == "HS Voice" {
      window.orderOut(nil)
    }
  }
}
