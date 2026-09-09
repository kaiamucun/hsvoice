import AVFoundation
import CoreAudio
import XCTest

@testable import HSVoice

final class AudioInputDevicesTests: XCTestCase {
  /// Smoke test against the real hardware: every Mac this runs on has at least
  /// a built-in microphone, and the system default must be one of the inputs.
  func testEnumeratesInputDevicesIncludingTheSystemDefault() throws {
    let devices = AudioInputDevices.available()
    try XCTSkipIf(devices.isEmpty, "No audio input device on this machine")
    XCTAssertTrue(devices.allSatisfy { !$0.uid.isEmpty && !$0.name.isEmpty })
    let defaultID = try XCTUnwrap(AudioInputDevices.defaultInputDeviceID())
    XCTAssertTrue(devices.contains { $0.id == defaultID })
    let first = devices[0]
    XCTAssertEqual(AudioInputDevices.device(forUID: first.uid), first)
    XCTAssertNil(AudioInputDevices.device(forUID: "no-such-device-uid"))
  }

  /// Regression test for the 1.7.0 crash `Failed to create tap due to format
  /// mismatch`. After `apply` re-routes the engine's input unit, the tap must
  /// use the format the new device actually delivers. AVAudioEngine keeps the
  /// previous device's rate on `outputFormat(forBus:)`, so reading that side
  /// made the second dictation throw whenever the engine's default aggregate
  /// ran at a different rate than the microphone (44.1 kHz vs 48 kHz).
  func testCaptureFormatFollowsAppliedDevice() throws {
    let engine = AVAudioEngine()
    let initialRate = engine.inputNode.outputFormat(forBus: 0).sampleRate
    let candidates = AudioInputDevices.available().filter {
      Self.nominalSampleRate(of: $0.id) != initialRate
    }
    guard let device = candidates.first else {
      throw XCTSkip("Every input device runs at the engine's initial rate; nothing to switch to")
    }
    XCTAssertTrue(AudioInputDevices.apply(preferredUID: device.uid, to: engine))

    let format = AudioInputDevices.captureFormat(of: engine)
    let expectedRate = Self.nominalSampleRate(of: device.id)
    guard format.sampleRate == expectedRate, format.channelCount > 0 else {
      XCTFail(
        "capture format \(format) does not follow \(device.name) at \(expectedRate) Hz; "
          + "AVFAudio would reject a tap in this format")
      return
    }

    // Two back-to-back sessions, exactly like consecutive dictations: with a
    // stale format the first install is skipped (config change pending) and
    // the second one raises an NSException. Both must be accepted.
    for _ in 1...2 {
      engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
      engine.prepare()
      RunLoop.main.run(until: Date().addingTimeInterval(0.3))
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
    }
  }

  private static func nominalSampleRate(of identifier: AudioDeviceID) -> Double {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyNominalSampleRate,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var rate: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    guard AudioObjectGetPropertyData(identifier, &address, 0, nil, &size, &rate) == noErr
    else { return 0 }
    return rate
  }
}
