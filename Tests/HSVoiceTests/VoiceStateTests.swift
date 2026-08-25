import XCTest

@testable import HSVoice

final class VoiceStateTests: XCTestCase {
  func testOnlyIdleUsesCompactPersistentOverlay() {
    XCTAssertEqual(VoiceState.idle.overlayPresentation, .compact)

    let expandedStates: [VoiceState] = [
      .requestingPermission,
      .listening,
      .processing,
      .success("入力しました"),
      .error("確認が必要です"),
    ]

    XCTAssertTrue(expandedStates.allSatisfy { $0.overlayPresentation == .expanded })
  }

  func testEveryOverlayStateHasVisibleStatusCopy() {
    let states: [VoiceState] = [
      .idle,
      .requestingPermission,
      .listening,
      .processing,
      .success("入力しました"),
      .error("確認が必要です"),
    ]

    XCTAssertTrue(states.allSatisfy { !$0.title.isEmpty && !$0.symbolName.isEmpty })
  }

  func testBusyStatesRejectConfigurationChanges() {
    let busyStates: [VoiceState] = [.requestingPermission, .listening, .processing]
    let settledStates: [VoiceState] = [.idle, .success("完了"), .error("確認")]

    XCTAssertTrue(busyStates.allSatisfy { !$0.allowsConfigurationChanges })
    XCTAssertTrue(settledStates.allSatisfy(\.allowsConfigurationChanges))
  }
}
