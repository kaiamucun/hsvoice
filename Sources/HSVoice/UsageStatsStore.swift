import Foundation

/// Per-day totals. Only counts — never the dictated text.
struct DayUsage: Codable, Equatable {
  var characters: Int = 0
  var dictations: Int = 0
}

/// Everything the companion needs to know about how HS Voice has been used,
/// as stored on disk. Pure data; `UsageSnapshot` derives the interesting
/// numbers (streaks, bests) from it.
struct UsageRecord: Codable, Equatable {
  var totalCharacters = 0
  var totalDictations = 0
  var firstDictationAt: Date?
  var longestDictation = 0
  /// Keyed by local calendar day, "yyyy-MM-dd".
  var days: [String: DayUsage] = [:]
  var applications: Set<String> = []
  var locales: Set<String> = []
  var flags: Set<String> = []
  /// Items the user has already looked at in the companion window — anything
  /// unlocked but not in here gets a NEW badge.
  var seenItemIDs: Set<String> = []
}

/// Moments of the day that unlock a hidden item.
enum UsageFlag: String {
  /// A dictation between midnight and 04:59.
  case nightOwl
  /// A dictation between 05:00 and 07:59.
  case earlyBird
  /// A dictation on a Saturday or Sunday.
  case weekend
}

/// Read-only view of the record with the derived numbers the catalog's
/// unlock conditions and the UI ask for. Computed once per render.
struct UsageSnapshot: Equatable {
  let totalCharacters: Int
  let totalDictations: Int
  let longestDictation: Int
  let todayCharacters: Int
  let todayDictations: Int
  /// Consecutive days with at least one dictation, ending today or — when
  /// today has none yet — yesterday.
  let streakDays: Int
  let longestStreakDays: Int
  /// Days on which at least one dictation happened.
  let activeDays: Int
  let maxDailyCharacters: Int
  /// Highest total over any 7 consecutive days.
  let maxWeeklyCharacters: Int
  /// 1 on the day of the first dictation, 2 the day after, …; 0 before any.
  let daysSinceFirstUse: Int
  let applicationCount: Int
  let languageCount: Int
  let flags: Set<UsageFlag>

  static let empty = UsageSnapshot(
    totalCharacters: 0, totalDictations: 0, longestDictation: 0, todayCharacters: 0,
    todayDictations: 0, streakDays: 0, longestStreakDays: 0, activeDays: 0,
    maxDailyCharacters: 0, maxWeeklyCharacters: 0, daysSinceFirstUse: 0,
    applicationCount: 0, languageCount: 0, flags: [])

  init(
    totalCharacters: Int, totalDictations: Int, longestDictation: Int, todayCharacters: Int,
    todayDictations: Int, streakDays: Int, longestStreakDays: Int, activeDays: Int,
    maxDailyCharacters: Int, maxWeeklyCharacters: Int, daysSinceFirstUse: Int,
    applicationCount: Int, languageCount: Int, flags: Set<UsageFlag>
  ) {
    self.totalCharacters = totalCharacters
    self.totalDictations = totalDictations
    self.longestDictation = longestDictation
    self.todayCharacters = todayCharacters
    self.todayDictations = todayDictations
    self.streakDays = streakDays
    self.longestStreakDays = longestStreakDays
    self.activeDays = activeDays
    self.maxDailyCharacters = maxDailyCharacters
    self.maxWeeklyCharacters = maxWeeklyCharacters
    self.daysSinceFirstUse = daysSinceFirstUse
    self.applicationCount = applicationCount
    self.languageCount = languageCount
    self.flags = flags
  }

  init(record: UsageRecord, now: Date, calendar: Calendar) {
    let today = UsageDay.key(for: now, calendar: calendar)
    let todayUsage = record.days[today] ?? DayUsage()
    let activeKeys = Set(record.days.filter { $0.value.dictations > 0 }.keys)

    // Streak: walk back from today (or yesterday when today is still empty).
    var streak = 0
    if !activeKeys.isEmpty {
      var cursor = calendar.startOfDay(for: now)
      if !activeKeys.contains(UsageDay.key(for: cursor, calendar: calendar)) {
        cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
      }
      while activeKeys.contains(UsageDay.key(for: cursor, calendar: calendar)) {
        streak += 1
        guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = previous
      }
    }

    // Longest streak and best week over the stored days, oldest first.
    let orderedDays = activeKeys.compactMap { key -> (Date, Int)? in
      guard let date = UsageDay.date(for: key, calendar: calendar) else { return nil }
      return (calendar.startOfDay(for: date), record.days[key]?.characters ?? 0)
    }.sorted { $0.0 < $1.0 }

    var longest = 0
    var run = 0
    var previousDate: Date?
    for (date, _) in orderedDays {
      if let previousDate,
        let expected = calendar.date(byAdding: .day, value: 1, to: previousDate),
        calendar.isDate(expected, inSameDayAs: date)
      {
        run += 1
      } else {
        run = 1
      }
      longest = max(longest, run)
      previousDate = date
    }

    var bestWeek = 0
    for (index, (endDate, _)) in orderedDays.enumerated() {
      guard let windowStart = calendar.date(byAdding: .day, value: -6, to: endDate) else {
        continue
      }
      var sum = 0
      var cursor = index
      while cursor >= 0, orderedDays[cursor].0 >= windowStart {
        sum += orderedDays[cursor].1
        cursor -= 1
      }
      bestWeek = max(bestWeek, sum)
    }

    var daysSinceFirst = 0
    if let first = record.firstDictationAt {
      let elapsed =
        calendar.dateComponents(
          [.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: now)
        ).day ?? 0
      daysSinceFirst = max(0, elapsed) + 1
    }

    self.init(
      totalCharacters: record.totalCharacters,
      totalDictations: record.totalDictations,
      longestDictation: record.longestDictation,
      todayCharacters: todayUsage.characters,
      todayDictations: todayUsage.dictations,
      streakDays: streak,
      longestStreakDays: longest,
      activeDays: activeKeys.count,
      maxDailyCharacters: record.days.values.map(\.characters).max() ?? 0,
      maxWeeklyCharacters: bestWeek,
      daysSinceFirstUse: daysSinceFirst,
      applicationCount: record.applications.count,
      languageCount: record.locales.count,
      flags: Set(record.flags.compactMap(UsageFlag.init(rawValue:)))
    )
  }
}

enum UsageDay {
  private static let formatterCache = NSCache<NSString, DateFormatter>()

  private static func formatter(for calendar: Calendar) -> DateFormatter {
    let cacheKey = "\(calendar.identifier)|\(calendar.timeZone.identifier)" as NSString
    if let cached = formatterCache.object(forKey: cacheKey) { return cached }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatterCache.setObject(formatter, forKey: cacheKey)
    return formatter
  }

  static func key(for date: Date, calendar: Calendar) -> String {
    formatter(for: calendar).string(from: date)
  }

  static func date(for key: String, calendar: Calendar) -> Date? {
    formatter(for: calendar).date(from: key)
  }
}

/// Counts how HS Voice is used — characters, dictations, days, apps — so the
/// companion can level up and unlock items. Never stores dictated text.
@MainActor
final class UsageStatsStore: ObservableObject {
  static let shared = UsageStatsStore()

  @Published private(set) var record: UsageRecord

  private let storageURL: URL
  private let fileManager: FileManager
  private let calendar: Calendar
  /// Days older than this are dropped; streak and best-week math only needs
  /// recent history, and the file stays small forever.
  private let retainedDays: Int

  init(
    storageURL: URL? = nil,
    fileManager: FileManager = .default,
    calendar: Calendar = .current,
    retainedDays: Int = 400
  ) {
    self.fileManager = fileManager
    self.calendar = calendar
    self.retainedDays = retainedDays
    if let storageURL {
      self.storageURL = storageURL
    } else {
      let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      self.storageURL =
        base
        .appendingPathComponent("HS Voice", isDirectory: true)
        .appendingPathComponent("usage.json")
    }
    record = Self.load(from: self.storageURL)
  }

  func snapshot(now: Date = Date()) -> UsageSnapshot {
    UsageSnapshot(record: record, now: now, calendar: calendar)
  }

  /// One completed dictation. `applicationName` is nil in clipboard-only mode.
  func recordDictation(
    characters: Int, applicationName: String?, localeIdentifier: String, at date: Date = Date()
  ) {
    guard characters > 0 else { return }
    var updated = record
    updated.totalCharacters += characters
    updated.totalDictations += 1
    updated.longestDictation = max(updated.longestDictation, characters)
    if updated.firstDictationAt == nil { updated.firstDictationAt = date }

    let key = UsageDay.key(for: date, calendar: calendar)
    var day = updated.days[key] ?? DayUsage()
    day.characters += characters
    day.dictations += 1
    updated.days[key] = day

    if let applicationName, !applicationName.isEmpty {
      updated.applications.insert(applicationName)
    }
    if !localeIdentifier.isEmpty {
      updated.locales.insert(localeIdentifier)
    }

    let hour = calendar.component(.hour, from: date)
    if hour < 5 { updated.flags.insert(UsageFlag.nightOwl.rawValue) }
    if (5..<8).contains(hour) { updated.flags.insert(UsageFlag.earlyBird.rawValue) }
    if calendar.isDateInWeekend(date) { updated.flags.insert(UsageFlag.weekend.rawValue) }

    prune(&updated, now: date)
    record = updated
    save()
  }

  func markItemsSeen(_ ids: Set<String>) {
    guard !ids.isSubset(of: record.seenItemIDs) else { return }
    record.seenItemIDs.formUnion(ids)
    save()
  }

  /// Wipes every count. Customization (name, worn items) lives in settings
  /// and is untouched.
  func reset() {
    record = UsageRecord()
    save()
  }

  private func prune(_ record: inout UsageRecord, now: Date) {
    guard record.days.count > retainedDays else { return }
    let keep = record.days.keys.sorted().suffix(retainedDays)
    record.days = record.days.filter { keep.contains($0.key) }
  }

  private static func load(from url: URL) -> UsageRecord {
    guard let data = try? Data(contentsOf: url) else { return UsageRecord() }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode(UsageRecord.self, from: data)) ?? UsageRecord()
  }

  private func save() {
    do {
      try fileManager.createDirectory(
        at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(record)
      try data.write(to: storageURL, options: .atomic)
    } catch {
      NSLog("HS Voice: usage stats could not be saved: %@", error.localizedDescription)
    }
  }
}

/// Thousands-grouped numbers ("185,112") the same way in every UI language.
enum UsageFormat {
  private static let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = ","
    return formatter
  }()

  static func number(_ value: Int) -> String {
    formatter.string(from: NSNumber(value: value)) ?? String(value)
  }
}
