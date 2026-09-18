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

  func testPersistsTranslatedSourceText() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let entry = HistoryEntry(
      text: "The meeting is at 4.", applicationName: "Mail", localeIdentifier: "ja-JP",
      sourceText: "会議は4時です。")
    HistoryStore(storageURL: file).add(entry)
    XCTAssertEqual(HistoryStore(storageURL: file).entries, [entry])
  }

  func testReloadsLegacyEntriesWithoutSourceText() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let json = """
      [{"applicationName":"Notes","createdAt":0,"id":"00000000-0000-0000-0000-000000000001","localeIdentifier":"ja-JP","text":"社内テスト"}]
      """
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(json.utf8).write(to: file)

    let store = HistoryStore(storageURL: file)
    XCTAssertEqual(store.entries.count, 1)
    XCTAssertEqual(store.entries.first?.text, "社内テスト")
    XCTAssertNil(store.entries.first?.sourceText)
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
