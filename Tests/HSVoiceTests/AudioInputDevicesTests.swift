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
}
