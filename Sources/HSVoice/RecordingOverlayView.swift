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
    .padding(.bottom, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityStatus)
  }

  private var compactStatus: some View {
    Capsule()
      .fill(Color.primary.opacity(0.76))
      .frame(width: 54, height: 8)
      .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
  }

  private var expandedStatus: some View {
    HStack(spacing: 9) {
      ZStack {
        Circle()
          .fill(statusColor.opacity(0.14))
        Image(systemName: model.state.symbolName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(statusColor)
          .symbolEffect(.pulse, isActive: model.state == .listening)
      }
      .frame(width: 26, height: 26)

      if model.state == .listening {
        AudioLevelView(
          level: model.audioLevel,
          fillColor: .teal,
          trackColor: .teal.opacity(0.12)
        )
        .frame(width: 96)

        Text(model.formattedRecordingDuration)
          .font(.system(.caption2, design: .monospaced).weight(.semibold))
          .foregroundStyle(.secondary)
          .monospacedDigit()
      } else {
        Text(expandedMessage)
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(model.state.isError ? Color.orange : Color.primary)
          .lineLimit(1)
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 12)
    .padding(.vertical, 6)
    .background(.ultraThickMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(.primary.opacity(0.1), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.14), radius: 9, y: 4)
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
