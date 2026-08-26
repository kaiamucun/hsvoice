import SwiftUI

/// Availability shims that let HS Voice run on macOS 13 while keeping the
/// nicer effects on newer systems.
extension View {

  /// `symbolEffect(.pulse)` exists from macOS 14; on macOS 13 the symbol is
  /// simply shown without the pulse.
  @ViewBuilder
  func pulseSymbol(isActive: Bool) -> some View {
    if #available(macOS 14.0, *) {
      symbolEffect(.pulse, isActive: isActive)
    } else {
      self
    }
  }
}

/// Replacement for `ContentUnavailableView` (macOS 14+) that renders the same
/// shape on macOS 13.
struct EmptyStatePlaceholder: View {
  let title: String
  let systemImage: String
  let description: String

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(.tertiary)
      Text(title)
        .font(.title3.weight(.semibold))
      Text(description)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(30)
  }
}
