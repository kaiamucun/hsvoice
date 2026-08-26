import AppKit
import SwiftUI

struct MenuBarView: View {
  @Environment(\.openWindow) private var openWindow
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  private var isRecording: Bool { model.state == .listening }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)

      recordingCard
        .padding(.horizontal, 12)

      quickControls
        .padding(.horizontal, 18)
        .padding(.top, 12)

      if !model.lastTranscript.isEmpty, !isRecording {
        lastTranscriptCard
          .padding(.horizontal, 18)
          .padding(.top, 14)
      }

      Divider()
        .padding(.top, 14)

      footer
        .padding(10)
    }
    .frame(width: 392)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.10, green: 0.78, blue: 0.68),
                Color(red: 0.12, green: 0.45, blue: 0.96),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        Image(systemName: "waveform")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(.white)
      }
      .frame(width: 34, height: 34)

      VStack(alignment: .leading, spacing: 2) {
        Text("HS Voice")
          .font(.system(size: 15, weight: .semibold, design: .rounded))
        Text(L.t("社内向けスマート音声入力", "Smart in-house dictation", "面向公司内部的智能语音输入", "사내용 스마트 음성 입력"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 5) {
        Circle()
          .fill(statusColor)
          .frame(width: 7, height: 7)
        Text(model.state.title)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }
    }
  }

  private var recordingCard: some View {
    Button {
      model.toggleListening()
    } label: {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(.white.opacity(0.18))
            Image(systemName: model.state.symbolName)
              .font(.system(size: 21, weight: .semibold))
              .pulseSymbol(isActive: isRecording)
          }
          .frame(width: 44, height: 44)

          VStack(alignment: .leading, spacing: 3) {
            Text(primaryActionTitle)
              .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(model.stateDetail)
              .font(.caption)
              .lineLimit(2)
              .foregroundStyle(.white.opacity(0.78))
          }

          Spacer(minLength: 8)

          shortcutCaps
        }

        if isRecording || model.state == .processing {
          VStack(alignment: .leading, spacing: 8) {
            AudioLevelView(level: model.audioLevel)
            Text(
              model.partialTranscript.isEmpty
                ? L.t("話してください…", "Start speaking…", "请开始说话…", "말씀해 주세요…") : model.partialTranscript)
              .font(.system(size: 12.5))
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(.white.opacity(model.partialTranscript.isEmpty ? 0.62 : 0.92))
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(.white)
      .background(cardGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(model.state == .requestingPermission || model.state == .processing)
    .animation(.easeOut(duration: 0.18), value: model.state)
  }

  private var lastTranscriptCard: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Label(L.t("直前の入力", "Last dictation", "上次输入", "마지막 입력"), systemImage: "clock.arrow.circlepath")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Text(model.lastTranscript)
        .font(.system(size: 12.5))
        .lineLimit(3)
        .textSelection(.enabled)

      HStack(spacing: 12) {
        Button {
          model.repeatLastTranscript()
        } label: {
          Label(repeatActionTitle, systemImage: "arrow.clockwise")
            .font(.caption)
        }
        .buttonStyle(.borderless)

        Button {
          model.copyLastTranscript()
        } label: {
          Label(L.t("コピー", "Copy", "复制", "복사"), systemImage: "doc.on.doc")
            .font(.caption)
        }
        .buttonStyle(.borderless)

        Spacer()

        if model.canUndoLastInsertion {
          Button {
            model.undoLastInsertion()
          } label: {
            Label(L.t("取り消す", "Undo", "撤销", "취소"), systemImage: "arrow.uturn.backward")
              .font(.caption)
          }
          .buttonStyle(.borderless)
          .help(
            L.t(
              "自動入力の直後8秒間、同じ入力先でのみ使えます", "Available for 8 seconds after auto-typing, in the same app only",
              "自动输入后8秒内且同一目标应用中可用", "자동 입력 후 8초 동안 같은 대상 앱에서만 사용할 수 있습니다"))
        }
      }
    }
  }

  private var quickControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 3) {
          Label(L.t("話す言語", "Spoken language", "所说语言", "말하는 언어"), systemImage: "character.bubble")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Picker(L.t("話す言語", "Spoken language", "所说语言", "말하는 언어"), selection: $settings.localeIdentifier) {
            ForEach(VoiceLocale.recommended) { locale in
              Text(locale.nativeName).tag(locale.identifier)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        Divider()
          .frame(height: 42)

        VStack(alignment: .leading, spacing: 3) {
          Label(
            L.t("入力方法", "Insertion", "输入方式", "입력 방식"), systemImage: settings.insertionMode.symbolName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Picker(
            L.t("入力方法", "Insertion", "输入方式", "입력 방식"),
            selection: Binding(
              get: { settings.insertionMode },
              set: { model.setInsertionMode($0) }
            )
          ) {
            ForEach(InsertionMode.allCases) { mode in
              Text(mode.shortLabel).tag(mode)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      if settings.insertionMode == .automatic && !model.permissions.accessibilityGranted {
        Label(
          L.t(
            "権限がないため結果はコピーされます", "No permission — results will be copied instead",
            "因缺少权限，结果将改为复制", "권한이 없어 결과는 복사됩니다"),
          systemImage: "exclamationmark.circle")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
    }
    .padding(11)
    .background(
      Color.primary.opacity(0.035),
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
    .disabled(model.state.isBusy)
  }

  private var footer: some View {
    HStack(spacing: 2) {
      Button {
        model.showHistory()
      } label: {
        Label(L.t("履歴", "History", "历史", "기록"), systemImage: "clock")
      }
      .buttonStyle(MenuFooterButtonStyle())

      Button {
        openWindow(id: "settings")
      } label: {
        Label(L.t("設定", "Settings", "设置", "설정"), systemImage: "gearshape")
      }
      .buttonStyle(MenuFooterButtonStyle())

      Button {
        if settings.completedOnboarding {
          model.showOnboarding()
        } else {
          openWindow(id: "settings")
        }
      } label: {
        Label(L.t("権限", "Permissions", "权限", "권한"), systemImage: "checkmark.shield")
      }
      .buttonStyle(MenuFooterButtonStyle())

      Spacer()

      Button {
        NSApp.terminate(nil)
      } label: {
        Image(systemName: "power")
          .frame(width: 26, height: 24)
      }
      .buttonStyle(.plain)
      .help(L.t("HS Voiceを終了", "Quit HS Voice", "退出HS Voice", "HS Voice 종료"))
    }
    .font(.caption)
  }

  private var shortcutCaps: some View {
    HStack(spacing: 4) {
      ForEach(model.settings.shortcutChoice.keyLabels, id: \.self) { label in
        KeyCap(text: label, wide: label == "Space")
      }
    }
    .opacity(model.shortcutAvailable ? 1 : 0.45)
  }

  private var primaryActionTitle: String {
    switch model.state {
    case .idle, .success, .error:
      return L.t("クリックして話す", "Click to speak", "点击开始说话", "클릭해서 말하기")
    case .requestingPermission:
      return L.t("権限を確認中", "Checking permissions", "正在检查权限", "권한 확인 중")
    case .listening: return L.t("クリックして終了", "Click to stop", "点击结束", "클릭해서 종료")
    case .processing: return L.t("テキストを準備中", "Preparing text", "正在准备文本", "텍스트 준비 중")
    }
  }

  private var repeatActionTitle: String {
    settings.insertionMode == .automatic
      ? L.t("もう一度入力", "Insert again", "再次输入", "다시 입력")
      : L.t("もう一度コピー", "Copy again", "再次复制", "다시 복사")
  }

  private var statusColor: Color {
    switch model.state {
    case .listening: return .red
    case .processing, .requestingPermission: return .orange
    case .error: return .yellow
    default: return Color(red: 0.16, green: 0.76, blue: 0.51)
    }
  }

  private var cardGradient: LinearGradient {
    let colors: [Color]
    switch model.state {
    case .listening:
      colors = [
        Color(red: 0.12, green: 0.31, blue: 0.49), Color(red: 0.06, green: 0.69, blue: 0.62),
      ]
    case .error:
      colors = [
        Color(red: 0.49, green: 0.22, blue: 0.21), Color(red: 0.78, green: 0.38, blue: 0.21),
      ]
    default:
      colors = [
        Color(red: 0.10, green: 0.22, blue: 0.38), Color(red: 0.10, green: 0.48, blue: 0.70),
      ]
    }
    return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

private struct KeyCap: View {
  let text: String
  var wide = false

  var body: some View {
    Text(text)
      .font(.system(size: 10, weight: .semibold, design: .rounded))
      .frame(minWidth: wide ? 42 : 22, minHeight: 22)
      .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .stroke(.white.opacity(0.2), lineWidth: 0.5)
      }
  }
}

private struct MenuFooterButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 8)
      .frame(height: 28)
      .background(
        configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear,
        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
      )
  }
}

struct AudioLevelView: View {
  let level: Double
  var fillColor: Color = .white
  var trackColor: Color = .white.opacity(0.13)

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(trackColor)
        Capsule()
          .fill(fillColor.opacity(0.82))
          .frame(width: max(8, proxy.size.width * level))
      }
    }
    .frame(height: 4)
    .animation(.linear(duration: 0.08), value: level)
  }
}
