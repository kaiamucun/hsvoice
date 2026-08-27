import AppKit
import SwiftUI

/// Compact keycap row for displaying a shortcut in the settings window.
struct ShortcutKeyCapsView: View {
  let labels: [String]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
        Text(label)
          .font(.system(size: 11.5, weight: .semibold, design: .rounded))
          .padding(.horizontal, 7)
          .frame(minWidth: 26)
          .frame(height: 22)
          .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(Color.primary.opacity(0.07))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .strokeBorder(Color.primary.opacity(0.16))
          )
      }
    }
  }
}

/// A "press the keys — or the mouse button — you want" shortcut recorder.
///
/// While recording, event monitors capture the next non-modifier key press or
/// middle/side mouse button press together with the modifiers held at that
/// moment and hand it to `onCapture`. A bare `esc` cancels. `onBegin` /
/// `onEnd` bracket the capture so the app can suspend its own global
/// shortcuts while keys are tried out (`onCapture` is called before `onEnd`,
/// so re-registration on ending already sees the newly chosen combination).
/// `captureDisabled` greys out the "Change…" button while another recorder on
/// the same screen is capturing.
struct ShortcutRecorderField: View {
  let keyLabels: [String]
  var captureDisabled = false
  /// Returns true when the combo is already used elsewhere in the app; the
  /// recorder then refuses it and keeps listening.
  var isConflicting: (InputCombo) -> Bool = { _ in false }
  let onBegin: () -> Void
  let onEnd: () -> Void
  let onCapture: (InputCombo) -> Void

  private enum Hint {
    case needsModifier
    case conflict
  }

  @State private var isRecording = false
  @State private var monitors: [Any] = []
  @State private var hint: Hint?

  var body: some View {
    VStack(alignment: .trailing, spacing: 4) {
      HStack(spacing: 8) {
        if isRecording {
          Text(
            L.t(
              "キーかマウスボタンを押してください…", "Press keys or a mouse button…",
              "请按下按键或鼠标按钮…", "키 또는 마우스 버튼을 눌러 주세요…"))
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
          Button(L.t("キャンセル", "Cancel", "取消", "취소")) {
            cancelRecording()
          }
          .controlSize(.small)
        } else {
          ShortcutKeyCapsView(labels: keyLabels)
          Button(L.t("変更…", "Change…", "更改…", "변경…")) {
            startRecording()
          }
          .controlSize(.small)
          .disabled(captureDisabled)
        }
      }
      if let hint {
        Text(hintText(hint))
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .onDisappear { cancelRecording() }
    // Switching to another app while recording would leave every global
    // shortcut suspended with no visible reason — treat it as a cancel.
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
    ) { _ in
      cancelRecording()
    }
  }

  private func hintText(_ hint: Hint) -> String {
    switch hint {
    case .needsModifier:
      return L.t(
        "修飾キー（⌃⌥⇧⌘）と組み合わせてください。F1〜F19とマウスの中央・サイドボタンは単体でも使えます。",
        "Combine with a modifier key (⌃⌥⇧⌘). F1–F19 and middle/side mouse buttons may be used alone.",
        "请与修饰键（⌃⌥⇧⌘）组合使用。F1〜F19及鼠标中键/侧键可单独使用。",
        "수정 키（⌃⌥⇧⌘）와 조합해 주세요. F1〜F19와 마우스 가운데/사이드 버튼은 단독으로도 사용할 수 있습니다.")
    case .conflict:
      return L.t(
        "この組み合わせは既に他の機能に割り当てられています。",
        "This combination is already assigned to another function.",
        "该组合已分配给其他功能。",
        "이 조합은 이미 다른 기능에 할당되어 있습니다.")
    }
  }

  private func startRecording() {
    guard !isRecording else { return }
    isRecording = true
    hint = nil
    onBegin()
    if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
      handleKeyDown(event)
      // Recorded keystrokes must never reach the settings window's controls.
      return nil
    }) {
      monitors.append(keyMonitor)
    }
    // Middle/side mouse buttons are recordable too. The local monitor covers
    // clicks on the settings window itself; the global one lets the user press
    // the button anywhere (left/right clicks are never captured, so the
    // Cancel button stays clickable).
    if let mouseLocal = NSEvent.addLocalMonitorForEvents(
      matching: .otherMouseDown,
      handler: { event in
        handleMouseDown(event)
        return nil
      })
    {
      monitors.append(mouseLocal)
    }
    if let mouseGlobal = NSEvent.addGlobalMonitorForEvents(
      matching: .otherMouseDown,
      handler: { event in
        handleMouseDown(event)
      })
    {
      monitors.append(mouseGlobal)
    }
  }

  private func handleKeyDown(_ event: NSEvent) {
    let modifiers = KeyCombo.carbonModifiers(from: event.modifierFlags)

    // A bare esc cancels the recording (esc plus modifiers is recordable).
    if event.keyCode == 53, modifiers == 0 {
      cancelRecording()
      return
    }

    accept(.key(KeyCombo(keyCode: event.keyCode, carbonModifiers: modifiers)))
  }

  private func handleMouseDown(_ event: NSEvent) {
    accept(
      .mouse(
        MouseButtonCombo(
          buttonNumber: Int32(event.buttonNumber),
          carbonModifiers: KeyCombo.carbonModifiers(from: event.modifierFlags)
        )))
  }

  private func accept(_ combo: InputCombo) {
    guard combo.isUsableAsGlobalShortcut else {
      hint = .needsModifier
      return
    }
    guard !isConflicting(combo) else {
      hint = .conflict
      return
    }

    tearDownMonitors()
    isRecording = false
    hint = nil
    onCapture(combo)
    onEnd()
  }

  private func cancelRecording() {
    tearDownMonitors()
    hint = nil
    guard isRecording else { return }
    isRecording = false
    onEnd()
  }

  private func tearDownMonitors() {
    for monitor in monitors {
      NSEvent.removeMonitor(monitor)
    }
    monitors = []
  }
}
