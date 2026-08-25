import AppKit
import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var permissions: PermissionsManager

  init(model: AppModel) {
    self.model = model
    _permissions = ObservedObject(wrappedValue: model.permissions)
  }

  var body: some View {
    VStack(spacing: 0) {
      hero
        .padding(.horizontal, 44)
        .padding(.top, 42)

      VStack(spacing: 12) {
        PermissionRow(
          symbol: "mic.fill",
          title: "マイク",
          detail: "声を取り込むために使用します",
          granted: permissions.microphoneGranted,
          action: permissions.openMicrophoneSettings
        )
        PermissionRow(
          symbol: "waveform.badge.magnifyingglass",
          title: "音声認識",
          detail: "話した内容をテキストに変換します",
          granted: permissions.speechGranted,
          action: permissions.openSpeechSettings
        )
        PermissionRow(
          symbol: "text.cursor",
          title: "アクセシビリティ（自動入力）",
          detail: "許可しない場合も、結果をコピーして利用できます",
          granted: permissions.accessibilityGranted,
          action: model.requestAutomaticInsertionPermission
        )
      }
      .padding(.horizontal, 44)
      .padding(.top, 28)

      Spacer()

      VStack(spacing: 12) {
        if !permissions.canTranscribe {
          Button {
            Task {
              await model.requestPermissions()
            }
          } label: {
            Label("セットアップを開始", systemImage: "checkmark.shield.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        } else if !permissions.canInsertText {
          Button {
            model.requestAutomaticInsertionPermission()
          } label: {
            Label("自動入力を有効にする", systemImage: "text.cursor")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)

          Button("コピーだけで使う") {
            model.useClipboardOnlyAndCompleteOnboarding()
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
        } else {
          Button {
            model.completeOnboarding()
          } label: {
            Label("HS Voiceを使い始める", systemImage: "arrow.right.circle.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .tint(.teal)
        }

        HStack(spacing: 6) {
          Text("準備ができたら")
          ForEach(model.settings.shortcutChoice.keyLabels, id: \.self) { label in
            Text(label)
              .keyCap(wide: label == "Space")
          }
          Text(
            model.settings.activationMode == .hold
              ? "を押しながら話します" : "で録音を開始します"
          )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 44)
      .padding(.bottom, 36)
    }
    .frame(minWidth: 680, minHeight: 560)
    .background(
      LinearGradient(
        colors: [Color.teal.opacity(0.08), Color.clear, Color.blue.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .onAppear {
      model.refreshPermissions()
      model.completeOnboardingIfReady()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      model.refreshPermissions()
      model.completeOnboardingIfReady()
    }
  }

  private var hero: some View {
    VStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(
            LinearGradient(
              colors: [.teal, .blue],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        Image(systemName: "waveform")
          .font(.system(size: 36, weight: .bold))
          .foregroundStyle(.white)
      }
      .frame(width: 76, height: 76)
      .shadow(color: .teal.opacity(0.28), radius: 22, y: 9)

      VStack(spacing: 7) {
        Text("話すだけで、どこにでも入力。")
          .font(.system(size: 27, weight: .bold, design: .rounded))
        Text("HS Voiceはメニューバーに常駐し、自然な音声をカーソル位置へ届けます。")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Text("初期設定済み：日本語・fnキー・押している間に録音")
          .font(.caption.weight(.medium))
          .foregroundStyle(.teal)
      }
    }
  }
}

struct PermissionRow: View {
  let symbol: String
  let title: String
  let detail: String
  let granted: Bool
  let action: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(granted ? .teal : .secondary)
        .frame(width: 38, height: 38)
        .background(
          (granted ? Color.teal : Color.secondary).opacity(0.1),
          in: RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if granted {
        Label("許可済み", systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
      } else {
        Button("設定を開く", action: action)
          .controlSize(.small)
      }
    }
    .padding(13)
    .background(
      Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    }
  }
}

extension View {
  fileprivate func keyCap(wide: Bool = false) -> some View {
    self
      .font(.system(size: 10, weight: .semibold, design: .rounded))
      .frame(minWidth: wide ? 38 : 20, minHeight: 20)
      .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
      .overlay {
        RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.18), lineWidth: 0.5)
      }
  }
}
