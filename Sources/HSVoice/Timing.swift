import Foundation

/// Every user-perceived delay in HS Voice, in one place.
///
/// Dictation latency is the sum of several small waits that are easy to lose track
/// of when they live as literals inside three different services. Collecting them
/// here makes the end-to-end cost of "release the key, see the text" reviewable,
/// and keeps tuning from turning into a hunt through the call graph.
enum Timing {

  // MARK: Recognition finalization

  /// How long to wait for the recognizer's first word *after* the audio ends.
  ///
  /// `SFSpeechRecognitionTask` normally stops revising its transcript well before it
  /// delivers `isFinal`, and under on-device recognition it sometimes never delivers
  /// `isFinal` at all — so a fixed timeout charged every dictation for the worst
  /// case. But the server-backed recognizer often needs half a second or more after
  /// `endAudio()` before it sends its best revision, so finalization cannot start
  /// counting silence until it has heard something post-stop.
  static let recognitionSettleWindow: TimeInterval = 0.9

  /// Once a result has arrived after the audio ended, the recognizer is actively
  /// revising. Finalize as soon as it goes quiet for this long.
  static let recognitionQuietWindow: TimeInterval = 0.32

  /// A longer grace period while nothing at all has been recognized, so a slow first
  /// result is not mistaken for silence.
  static let recognitionEmptyQuietWindow: TimeInterval = 1.0

  /// Hard ceiling. A stalled recognizer must never hold the transcript hostage.
  static let recognitionFinalizationDeadline: TimeInterval = 2.0

  /// Hard ceiling for the macOS 26 SpeechAnalyzer engine's finalization. The
  /// analyzer usually finalizes in well under a second; this only guards a
  /// stalled session.
  static let analyzerFinalizationDeadline: TimeInterval = 3.0

  // MARK: Recording start

  /// Microphone audio captured during this first slice of a recording is
  /// discarded instead of being fed to the recognizer. Capture begins the
  /// instant the shortcut fires, so the first buffers carry the fn key's
  /// click and the start sound cue — a noise burst that Japanese recognition
  /// in particular transcribes as hallucinated fragments (「あ」「。」「はい。」)
  /// glued to the head of every dictation. People need a beat to begin
  /// speaking after pressing the key, so the window costs no real words;
  /// the level meter is deliberately not gated, so the UI still reacts
  /// immediately.
  static let initialAudioDiscardWindow: TimeInterval = 0.35

  // MARK: Text insertion

  /// Poll interval while waiting for the target application to come forward.
  static let activationPollInterval: TimeInterval = 0.01

  /// Give up on activation after this long and fall back to clipboard-only.
  static let activationTimeout: TimeInterval = 0.35

  /// Settling delay before typing the first synthesized keystroke when the target
  /// application never lost focus.
  static let insertionSettleDelay: TimeInterval = 0.02

  /// Longer settle when HS Voice actually had to switch applications, because the
  /// newly activated app still has to install its own key handling.
  static let insertionSettleDelayAfterActivation: TimeInterval = 0.045

  /// Pause between synthesized-keystroke chunks. Fast enough to feel instant for a
  /// full transcript, slow enough that sluggish event queues keep every character.
  static let insertionChunkInterval: TimeInterval = 0.004

  // MARK: Recording UI

  /// Recording timer tick. The visible duration only has one-second resolution, so
  /// the model publishes a change at most once per second regardless of this value.
  static let recordingTick: TimeInterval = 0.25

  /// Audio level is pushed into SwiftUI at most this often. The microphone tap fires
  /// roughly 47 times a second; ~30 updates a second is enough for fluid meter
  /// motion once the level is envelope-smoothed, while staying below the tap rate.
  static let audioLevelUpdateInterval: TimeInterval = 1.0 / 30.0

  /// Level changes smaller than this are not worth a redraw. Silence therefore costs
  /// no UI work at all. Small, because the envelope follower below already removes
  /// buffer-to-buffer jitter — a larger threshold visibly froze the meter between
  /// updates, which read as stepping.
  static let audioLevelSignificantChange = 0.005

  /// Attack time constant of the meter's envelope follower: how quickly the shown
  /// level rises toward a louder input. Short, so speech onsets still feel live.
  static let audioLevelAttackTime: TimeInterval = 0.05

  /// Release time constant: how quickly the shown level falls back in quiet
  /// moments. Longer than the attack — that asymmetry is what turns raw RMS
  /// flicker into a smooth breathing motion.
  static let audioLevelReleaseTime: TimeInterval = 0.3

  // MARK: Status reset

  static let successResetDelay: TimeInterval = 1.6
  static let recoverableErrorResetDelay: TimeInterval = 2.2
  static let startupErrorResetDelay: TimeInterval = 2.5
  static let recognitionErrorResetDelay: TimeInterval = 2.6

  // MARK: fn key watchdog

  /// Polling rate used until the event tap proves it is delivering events.
  static let functionKeyPollInterval: TimeInterval = 1.0 / 60.0

  /// Once the tap is confirmed it reports presses with no delay, so polling drops to
  /// a slow watchdog whose only job is repairing a transition the tap missed. This is
  /// the single largest idle-power saving in the app: the app is idle almost all the
  /// time, and the fast poll was reading HID modifier state 60 times a second.
  static let functionKeyWatchdogInterval: TimeInterval = 0.1
}
