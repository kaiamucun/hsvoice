import Foundation
import XCTest

@testable import HSVoice

@MainActor
final class UsageStatsStoreTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
  }

  private func date(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: string)!
  }

  private func makeStore(retainedDays: Int = 400) -> (UsageStatsStore, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent("usage.json")
    return (
      UsageStatsStore(storageURL: file, calendar: calendar, retainedDays: retainedDays), file
    )
  }

  func testRecordsTotalsPerDayAndPersists() {
    let (store, file) = makeStore()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    store.recordDictation(
      characters: 120, applicationName: "Notes", localeIdentifier: "ja-JP",
      at: date("2026-10-19 10:00"))
    store.recordDictation(
      characters: 30, applicationName: "Slack", localeIdentifier: "en-US",
      at: date("2026-10-19 11:00"))

    let reloaded = UsageStatsStore(storageURL: file, calendar: calendar)
    let snapshot = reloaded.snapshot(now: date("2026-10-19 12:00"))
    XCTAssertEqual(snapshot.totalCharacters, 150)
    XCTAssertEqual(snapshot.totalDictations, 2)
    XCTAssertEqual(snapshot.todayCharacters, 150)
    XCTAssertEqual(snapshot.todayDictations, 2)
    XCTAssertEqual(snapshot.longestDictation, 120)
    XCTAssertEqual(snapshot.applicationCount, 2)
    XCTAssertEqual(snapshot.languageCount, 2)
    XCTAssertEqual(snapshot.daysSinceFirstUse, 1)
    XCTAssertEqual(snapshot.activeDays, 1)
  }

  func testEmptyDictationsAndClipboardModeDoNotCountApps() {
    let (store, file) = makeStore()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    store.recordDictation(characters: 0, applicationName: "Notes", localeIdentifier: "ja-JP")
    store.recordDictation(characters: 10, applicationName: nil, localeIdentifier: "ja-JP")

    let snapshot = store.snapshot()
    XCTAssertEqual(snapshot.totalDictations, 1)
    XCTAssertEqual(snapshot.applicationCount, 0)
  }

  func testStreakCountsConsecutiveDaysAndSurvivesAnEmptyToday() {
    let (store, file) = makeStore()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    for day in ["2026-10-15", "2026-10-16", "2026-10-17"] {
      store.recordDictation(
        characters: 50, applicationName: nil, localeIdentifier: "ja-JP", at: date("\(day) 09:00"))
    }

    XCTAssertEqual(store.snapshot(now: date("2026-10-17 20:00")).streakDays, 3)
    // Nothing yet today: yesterday's streak is still alive.
    XCTAssertEqual(store.snapshot(now: date("2026-10-18 08:00")).streakDays, 3)
    // A full day skipped: the streak is gone.
    XCTAssertEqual(store.snapshot(now: date("2026-10-19 08:00")).streakDays, 0)
    XCTAssertEqual(store.snapshot(now: date("2026-10-19 08:00")).longestStreakDays, 3)
  }

  func testDaysSinceFirstUseAndBestWeek() {
    let (store, file) = makeStore()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    store.recordDictation(
      characters: 1000, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-01 09:00"))
    store.recordDictation(
      characters: 2000, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-05 09:00"))
    store.recordDictation(
      characters: 4000, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-12 09:00"))

    let snapshot = store.snapshot(now: date("2026-10-19 09:00"))
    XCTAssertEqual(snapshot.daysSinceFirstUse, 19)
    XCTAssertEqual(snapshot.maxDailyCharacters, 4000)
    // Oct 1 + Oct 5 fall within one 7-day window; Oct 12 stands alone.
    XCTAssertEqual(snapshot.maxWeeklyCharacters, 4000)

    store.recordDictation(
      characters: 1500, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-18 09:00"))
    XCTAssertEqual(store.snapshot(now: date("2026-10-19 09:00")).maxWeeklyCharacters, 5500)
  }

  func testTimeOfDayFlags() {
    let (store, file) = makeStore()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    store.recordDictation(
      characters: 10, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-19 14:00"))  // Monday afternoon
    XCTAssertTrue(store.snapshot().flags.isEmpty)

    store.recordDictation(
      characters: 10, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-20 01:30"))
    store.recordDictation(
      characters: 10, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-21 06:10"))
    store.recordDictation(
      characters: 10, applicationName: nil, localeIdentifier: "ja-JP",
      at: date("2026-10-24 10:00"))  // Saturday
    XCTAssertEqual(store.snapshot().flags, [.nightOwl, .earlyBird, .weekend])
  }

  func testPrunesOldDaysButKeepsTotals() {
    let (store, file) = makeStore(retainedDays: 3)
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    for day in 1...5 {
      store.recordDictation(
        characters: 10, applicationName: nil, localeIdentifier: "ja-JP",
        at: date(String(format: "2026-10-%02d 09:00", day)))
    }

    XCTAssertEqual(store.record.days.count, 3)
    XCTAssertEqual(store.record.days.keys.sorted().first, "2026-10-03")
    XCTAssertEqual(store.snapshot(now: date("2026-10-05 10:00")).totalCharacters, 50)
  }

  func testSeenItemsAndReset() {
    let (store, file) = makeStore()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    store.recordDictation(characters: 10, applicationName: nil, localeIdentifier: "ja-JP")
    store.markItemsSeen(["partyHat"])
    XCTAssertEqual(
      UsageStatsStore(storageURL: file, calendar: calendar).record.seenItemIDs, ["partyHat"])

    store.reset()
    XCTAssertEqual(store.record, UsageRecord())
    XCTAssertEqual(UsageStatsStore(storageURL: file, calendar: calendar).record, UsageRecord())
  }
}
