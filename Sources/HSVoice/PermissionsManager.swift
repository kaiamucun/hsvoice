import AVFoundation
import AppKit
import ApplicationServices
import Speech

@MainActor
final class PermissionsManager: ObservableObject {
  static let shared = PermissionsManager()

  @Published private(set) var microphoneGranted = false
  @Published private(set) var speechGranted = false
  @Published private(set) var accessibilityGranted = false

  var canTranscribe: Bool { microphoneGranted && speechGranted }
  var canInsertText: Bool { accessibilityGranted }

  func refresh() {
    microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
    accessibilityGranted = AXIsProcessTrusted()
  }

  func requestTranscriptionPermissions() async {
    if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
      microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
    } else {
      microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
      speechGranted = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status == .authorized)
        }
      }
    } else {
      speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
    }
  }

  @discardableResult
  func requestAccessibility(prompt: Bool = true) -> Bool {
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    return accessibilityGranted
  }

  func openMicrophoneSettings() {
    openPrivacySettings(anchor: "Privacy_Microphone")
  }

  func openSpeechSettings() {
    openPrivacySettings(anchor: "Privacy_SpeechRecognition")
  }

  func openAccessibilitySettings() {
    openPrivacySettings(anchor: "Privacy_Accessibility")
  }

  private func openPrivacySettings(anchor: String) {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
    else { return }
    NSWorkspace.shared.open(url)
  }
}
