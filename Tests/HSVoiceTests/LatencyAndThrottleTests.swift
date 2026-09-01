import XCTest

@testable import HSVoice

final class RecognitionFinalizationPolicyTests: XCTestCase {
  private let policy = RecognitionFinalizationPolicy(
    settleWindow: 0.9,
    quietWindow: 0.5,
    emptyQuietWindow: 1.2,
    deadline: 2.0
  )

  /// The regression this guards: finalizing on the mid-speech transcript because
  /// the recognizer had not yet sent its post-`endAudio` revision.
  func testWaitsForTheFirstResultAfterTheAudioEnds() {
    XCTAssertEqual(
      policy.quietDelay(hasTranscript: true, sawResultSinceStop: false),
      0.9,
      accuracy: 0.0001
    )
    XCTAssertGreaterThan(
      policy.quietDelay(hasTranscript: true, sawResultSinceStop: false),
      policy.quietDelay(hasTranscript: true, sawResultSinceStop: true)
    )
  }

  func testWaitsLongestWhenNothingHasBeenRecognizedAtAll() {
    XCTAssertEqual(
      policy.quietDelay(hasTranscript: false, sawResultSinceStop: false),
      1.2,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      policy.quietDelay(hasTranscript: false, sawResultSinceStop: true),
      1.2,
      accuracy: 0.0001
    )
  }

  func testEveryWindowIsShorterThanTheHardDeadline() {
    let shipping = RecognitionFinalizationPolicy()
    XCTAssertLessThan(shipping.quietWindow, shipping.deadline)
    XCTAssertLessThan(shipping.settleWindow, shipping.deadline)
    XCTAssertLessThan(shipping.emptyQuietWindow, shipping.deadline)
  }

  func testRepeatedPartialsCanNeverPushFinalizationPastTheDeadline() {
    XCTAssertEqual(
      policy.delayUntilFinalization(
        hasTranscript: true, sawResultSinceStop: true, elapsedSinceStop: 0),
      0.5,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      policy.delayUntilFinalization(
        hasTranscript: true, sawResultSinceStop: true, elapsedSinceStop: 1.8),
      0.2,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      policy.delayUntilFinalization(
        hasTranscript: true, sawResultSinceStop: true, elapsedSinceStop: 5),
      0,
      accuracy: 0.0001
    )
  }
}

final class AudioLevelThrottleTests: XCTestCase {
  func testFirstLevelIsAlwaysSent() {
    var throttle = AudioLevelThrottle(interval: 0.05, minimumChange: 0.02)
    XCTAssertTrue(throttle.shouldSend(level: 0.4, at: 100))
  }

  func testDropsUpdatesInsideTheRateLimit() {
    var throttle = AudioLevelThrottle(interval: 0.05, minimumChange: 0.02)
    XCTAssertTrue(throttle.shouldSend(level: 0.4, at: 100))
    XCTAssertFalse(throttle.shouldSend(level: 0.9, at: 100.02))
    XCTAssertTrue(throttle.shouldSend(level: 0.9, at: 100.06))
  }

  func testSilenceCostsNoUpdatesAtAll() {
    var throttle = AudioLevelThrottle(interval: 0.05, minimumChange: 0.02)
    XCTAssertTrue(throttle.shouldSend(level: 0, at: 100))
    for step in 1...50 {
      XCTAssertFalse(throttle.shouldSend(level: 0, at: 100 + Double(step) * 0.1))
    }
  }

  func testTinyFluctuationsDoNotTriggerARedraw() {
    var throttle = AudioLevelThrottle(interval: 0.05, minimumChange: 0.02)
    XCTAssertTrue(throttle.shouldSend(level: 0.50, at: 100))
    XCTAssertFalse(throttle.shouldSend(level: 0.505, at: 100.2))
    XCTAssertTrue(throttle.shouldSend(level: 0.60, at: 100.4))
  }
}

final class TimingBudgetTests: XCTestCase {
  /// Guards the tuning this optimization pass is built on, so a future edit cannot
  /// quietly reintroduce a fixed multi-second wait after every dictation.
  func testTypicalPostSpeechBudgetStaysUnderOneSecond() {
    // Target still frontmost, recognizer settles without a further revision.
    let typical = Timing.recognitionSettleWindow + Timing.insertionSettleDelay
    XCTAssertLessThan(typical, 1.0)
  }

  func testWorstCasePostSpeechBudgetIsBounded() {
    let worst =
      Timing.recognitionFinalizationDeadline
      + Timing.activationTimeout
      + Timing.insertionSettleDelayAfterActivation
    XCTAssertLessThan(worst, 2.5)
  }

  func testIdleWatchdogIsSlowerThanTheStartupPoll() {
    XCTAssertGreaterThan(Timing.functionKeyWatchdogInterval, Timing.functionKeyPollInterval)
  }
}


final class InitialAudioDiscardGateTests: XCTestCase {
  /// The regression this guards: the fn click and the start sound cue reaching
  /// the recognizer and being transcribed as 「あ」「。」「はい。」 at the head of
  /// every dictation.
  func testDiscardsExactlyTheConfiguredWindow() {
    // 0.35 s at 48 kHz = 16,800 frames; the tap delivers 1024-frame buffers.
    let gate = InitialAudioDiscardGate(sampleRate: 48_000, window: 0.35)
    var discarded = 0
    while gate.shouldDiscard(frameCount: 1024) {
      discarded += 1024
      XCTAssertLessThan(discarded, 48_000, "gate must not discard forever")
    }
    // Everything up to the window is dropped (the boundary buffer whole).
    XCTAssertGreaterThanOrEqual(discarded, 16_800)
    XCTAssertLessThan(discarded, 16_800 + 1024)
    // Once open, the gate stays open.
    XCTAssertFalse(gate.shouldDiscard(frameCount: 1024))
    XCTAssertFalse(gate.shouldDiscard(frameCount: 1))
  }

  func testZeroWindowPassesEverythingThrough() {
    let gate = InitialAudioDiscardGate(sampleRate: 48_000, window: 0)
    XCTAssertFalse(gate.shouldDiscard(frameCount: 1024))
  }

  func testInvalidSampleRatePassesEverythingThrough() {
    let gate = InitialAudioDiscardGate(sampleRate: 0, window: 0.35)
    XCTAssertFalse(gate.shouldDiscard(frameCount: 1024))
  }

  /// The window must stay short enough that a fast speaker's first word
  /// survives, and long enough to cover the click-plus-cue burst.
  func testWindowBudget() {
    XCTAssertGreaterThanOrEqual(Timing.initialAudioDiscardWindow, 0.2)
    XCTAssertLessThanOrEqual(Timing.initialAudioDiscardWindow, 0.5)
  }
}
