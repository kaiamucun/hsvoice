import SwiftUI

struct RecordingOverlayView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.clear

      Group {
        switch model.state.overlayPresentation {
        case .compact:
          compactStatus
            .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
        case .expanded:
          expandedStatus
            .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
        }
      }
      .animation(
        .spring(response: 0.3, dampingFraction: 0.84),
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
      Text("あと\(max(0, Int(remaining.rounded(.up))))秒")
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
      return "権限を確認中"
    case .processing:
      return "処理中"
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
      return "HS Voice 起動中。\(model.shortcutDisplayText)で音声入力できます"
    }
    return "HS Voice、\(model.state.title)。\(model.stateDetail)"
  }
}
