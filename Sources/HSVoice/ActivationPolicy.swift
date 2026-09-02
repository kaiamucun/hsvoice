import Foundation

/// What a shortcut press or release should do to the recording.
enum ActivationAction: Equatable {
  case begin
  case stop
  case none
}

/// Pure decision table behind the three activation modes, kept free of
/// AppModel state so it can be tested exhaustively.
///
/// `auto` is the mode most people never have to think about: a quick tap
/// starts a hands-free recording that the next tap stops, while holding the
/// key past `autoHoldThreshold` behaves like push-to-talk and stops on release.
enum ActivationPolicy {
  /// A press shorter than this is a tap (hands-free); longer is a hold.
  static let autoHoldThreshold: TimeInterval = 0.35

  static func onPress(mode: ActivationMode, isListening: Bool) -> ActivationAction {
    switch mode {
    case .hold:
      return isListening ? .none : .begin
    case .toggle, .auto:
      return isListening ? .stop : .begin
    }
  }

  static func onRelease(
    mode: ActivationMode, isListening: Bool, heldFor: TimeInterval
  ) -> ActivationAction {
    guard isListening else { return .none }
    switch mode {
    case .hold:
      return .stop
    case .toggle:
      return .none
    case .auto:
      return heldFor >= autoHoldThreshold ? .stop : .none
    }
  }
}
