import SwiftUI

struct RecordingOverlayView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings = SettingsStore.shared

  /// Shared geometry between the idle pill and the recording bar, so switching
  /// states morphs one capsule instead of popping two unrelated views.
  @Namespace private var capsuleMorph

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.clear

      Group {
        switch model.state.overlayPresentation {
        case .compact:
          // The idle pill can be turned off in settings; recording and result
          // states always show, so feedback during dictation is never lost.
          if settings.showIdleIndicator {
            compactStatus
              .matchedGeometryEffect(id: "statusCapsule", in: capsuleMorph)
              .transition(.opacity)
          }
        case .expanded:
          expandedStatus
            .matchedGeometryEffect(id: "statusCapsule", in: capsuleMorph)
            .transition(.opacity)
        }
      }
      .animation(
        .spring(response: 0.32, dampingFraction: 0.85),
        value: model.state.overlayPresentation
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityStatus)
  }

  /// Idle marker: a tiny pill with the waveform mark, so the dot at the bottom
  /// of the screen is recognizably HS Voice without claiming any real space.
  private var compactStatus: some View {
    Image(systemName: "waveform")
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.teal)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.ultraThinMaterial, in: Capsule())
      .overlay {
        Capsule().stroke(.primary.opacity(0.1), lineWidth: 0.5)
      }
      .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
  }

  private var expandedStatus: some View {
    HStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(statusColor.opacity(0.14))
        Image(systemName: model.state.symbolName)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(statusColor)
          .pulseSymbol(isActive: model.state == .listening)
      }
      .frame(width: 22, height: 22)

      if model.state == .listening {
        AudioLevelView(
          level: model.audioLevel,
          fillColor: .teal,
          trackColor: .teal.opacity(0.12)
        )
        .frame(width: 84)

        durationLabel
      } else {
        Text(expandedMessage)
          .font(.system(size: 11.5, weight: .medium, design: .rounded))
          .foregroundStyle(model.state.isError ? Color.orange : Color.primary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.ultraThickMaterial, in: Capsule())
    .overlay {
      Capsule().stroke(.primary.opacity(0.1), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.12), radius: 7, y: 3)
  }

  /// Elapsed time normally; an orange countdown once the 55-second safety stop
  /// is close, so it never cuts a sentence off by surprise.
  @ViewBuilder
  private var durationLabel: some View {
    let remaining = RecordingLimit.maximumDuration - model.recordingDuration
    if remaining <= RecordingLimit.countdownWarningRemaining {
      Text(
        L.t(
          "あと\(max(0, Int(remaining.rounded(.up))))秒", "\(max(0, Int(remaining.rounded(.up))))s left",
          "剩余\(max(0, Int(remaining.rounded(.up))))秒", "남은 시간 \(max(0, Int(remaining.rounded(.up))))초"))
        .font(.system(.caption2, design: .monospaced).weight(.semibold))
        .foregroundStyle(.orange)
        .monospacedDigit()
    } else {
      Text(model.formattedRecordingDuration)
        .font(.system(.caption2, design: .monospaced).weight(.semibold))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  private var expandedMessage: String {
    switch model.state {
    case .requestingPermission:
      return L.t("権限を確認中", "Checking permissions", "正在检查权限", "권한 확인 중")
    case .processing:
      return L.t("処理中", "Processing", "处理中", "처리 중")
    case .success, .error:
      return model.stateDetail
    case .idle, .listening:
      return ""
    }
  }

  private var statusColor: Color {
    switch model.state {
    case .error:
      return .orange
    case .success:
      return .green
    case .processing, .requestingPermission:
      return .secondary
    case .idle, .listening:
      return .teal
    }
  }

  private var accessibilityStatus: String {
    if model.state == .idle {
      return L.t(
        "HS Voice 起動中。\(model.shortcutDisplayText)で音声入力できます",
        "HS Voice is running. Dictate with \(model.shortcutDisplayText)",
        "HS Voice运行中。按\(model.shortcutDisplayText)即可语音输入",
        "HS Voice 실행 중. \(model.shortcutDisplayText)로 음성 입력할 수 있습니다")
    }
    return "HS Voice, \(model.state.title). \(model.stateDetail)"
  }
}
