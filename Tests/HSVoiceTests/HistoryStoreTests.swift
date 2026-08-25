import Foundation
import XCTest

@testable import HSVoice

@MainActor
final class HistoryStoreTests: XCTestCase {
  func testPersistsAndReloadsEntries() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let entry = HistoryEntry(text: "社内テスト", applicationName: "Notes", localeIdentifier: "ja-JP")
    let firstStore = HistoryStore(storageURL: file)
    firstStore.add(entry)

    let reloadedStore = HistoryStore(storageURL: file)
    XCTAssertEqual(reloadedStore.entries, [entry])
  }

  func testEnforcesMaximumEntryCount() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = HistoryStore(storageURL: file, maximumEntries: 3)
    for index in 0..<5 {
      store.add(
        HistoryEntry(text: "Entry \(index)", applicationName: nil, localeIdentifier: "en-US"))
    }

    XCTAssertEqual(store.entries.count, 3)
    XCTAssertEqual(store.entries.first?.text, "Entry 4")
    XCTAssertEqual(store.entries.last?.text, "Entry 2")
  }
}
