import AppKit
import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var permissions: PermissionsManager
  // Observed so a display-language switch repaints this window immediately.
  @ObservedObject private var settings = SettingsStore.shared

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
          title: L.t("マイク", "Microphone", "麦克风", "마이크"),
          detail: L.t("声を取り込むために使用します", "Used to capture your voice", "用于采集您的语音", "음성을 받아들이는 데 사용합니다"),
          granted: permissions.microphoneGranted,
          action: permissions.openMicrophoneSettings
        )
        PermissionRow(
          symbol: "waveform.badge.magnifyingglass",
          title: L.t("音声認識", "Speech Recognition", "语音识别", "음성 인식"),
          detail: L.t("話した内容をテキストに変換します", "Turns what you say into text", "将所说内容转换为文本", "말한 내용을 텍스트로 변환합니다"),
          granted: permissions.speechGranted,
          action: permissions.openSpeechSettings
        )
        PermissionRow(
          symbol: "text.cursor",
          title: L.t("アクセシビリティ（自動入力）", "Accessibility (auto-type)", "辅助功能（自动输入）", "손쉬운 사용（자동 입력）"),
          detail: L.t(
            "許可しない場合も、結果をコピーして利用できます", "Even without it, results can be used via copy",
            "即使不允许，也可通过复制使用结果", "허용하지 않아도 결과를 복사해서 사용할 수 있습니다"),
          granted: permissions.accessibilityGranted,
          action: model.requestAutomaticInsertionPermission
        )
        if permissions.canTranscribe && !permissions.accessibilityGranted {
          Text(
            L.t(
              "オンにしても「許可済み」にならない場合：システム設定の一覧で「HS Voice」を「−」で削除し、HS Voiceを再起動してからもう一度オンにしてください。",
              "If it never shows as granted: remove \"HS Voice\" from the list in System Settings with −, restart HS Voice, and enable it again.",
              "若开启后仍不显示“已允许”：请在系统设置列表中用“−”删除“HS Voice”，重启HS Voice后再重新开启。",
              "켜도 '허용됨'으로 표시되지 않으면: 시스템 설정 목록에서 'HS Voice'를 '−'로 삭제하고 HS Voice를 재시작한 뒤 다시 켜 주세요.")
          )
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            Label(
              L.t("セットアップを開始", "Start setup", "开始设置", "설정 시작"), systemImage: "checkmark.shield.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        } else if !permissions.canInsertText {
          Button {
            model.requestAutomaticInsertionPermission()
          } label: {
            Label(
              L.t("自動入力を有効にする", "Enable auto-type", "启用自动输入", "자동 입력 켜기"), systemImage: "text.cursor")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)

          Button(L.t("コピーだけで使う", "Use copy only", "仅使用复制", "복사만 사용")) {
            model.useClipboardOnlyAndCompleteOnboarding()
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
        } else {
          Button {
            model.completeOnboarding()
          } label: {
            Label(
              L.t("HS Voiceを使い始める", "Start using HS Voice", "开始使用HS Voice", "HS Voice 시작하기"),
              systemImage: "arrow.right.circle.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .tint(.teal)
        }

        HStack(spacing: 6) {
          Text(L.t("準備ができたら", "When you're ready,", "准备就绪后，", "준비가 되면"))
          ForEach(model.settings.shortcutChoice.keyLabels, id: \.self) { label in
            Text(label)
              .keyCap(wide: label == "Space")
          }
          Text(
            model.settings.activationMode != .toggle
              ? L.t("を押しながら話します", "— hold it and speak", "按住并说话", "를 누른 채 말하세요")
              : L.t("で録音を開始します", "— press it to start recording", "按下开始录音", "를 눌러 녹음을 시작하세요")
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
    // The user grants permissions in System Settings while this window stays
    // in the background, so the state must refresh without a click.
    // `.task` survives body re-evaluation and is cancelled when the window closes.
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        model.refreshPermissionStatus()
      }
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
        Text(L.t("話すだけで、どこにでも入力。", "Speak, and it types anywhere.", "只需说话，即可输入到任何位置。", "말하기만 하면 어디든 입력됩니다."))
          .font(.system(size: 27, weight: .bold, design: .rounded))
        Text(
          L.t(
            "HS Voiceはメニューバーに常駐し、自然な音声をカーソル位置へ届けます。",
            "HS Voice lives in the menu bar and delivers your natural speech to the cursor.",
            "HS Voice常驻菜单栏，将自然语音送达光标位置。",
            "HS Voice는 메뉴 막대에 상주하며 자연스러운 음성을 커서 위치로 전달합니다."))
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Text(
          L.t(
            "初期設定済み：日本語・fnキー・押している間に録音", "Preconfigured: Japanese · fn key · hold to record",
            "已预设：日语、fn键、按住录音", "기본 설정: 일본어 · fn 키 · 누르는 동안 녹음"))
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
        Label(L.t("許可済み", "Granted", "已允许", "허용됨"), systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.teal)
      } else {
        Button(L.t("設定を開く", "Open Settings", "打开设置", "설정 열기"), action: action)
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
