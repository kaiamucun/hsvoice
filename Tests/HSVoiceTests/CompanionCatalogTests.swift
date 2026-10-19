import Foundation
import XCTest

@testable import HSVoice

final class CompanionCatalogTests: XCTestCase {
  private func snapshot(
    totalCharacters: Int = 0, totalDictations: Int = 0, longestDictation: Int = 0,
    streakDays: Int = 0, longestStreakDays: Int = 0, activeDays: Int = 0,
    maxDailyCharacters: Int = 0, maxWeeklyCharacters: Int = 0, daysSinceFirstUse: Int = 0,
    applicationCount: Int = 0, languageCount: Int = 0, flags: Set<UsageFlag> = []
  ) -> UsageSnapshot {
    UsageSnapshot(
      totalCharacters: totalCharacters, totalDictations: totalDictations,
      longestDictation: longestDictation, todayCharacters: 0, todayDictations: 0,
      streakDays: streakDays, longestStreakDays: longestStreakDays, activeDays: activeDays,
      maxDailyCharacters: maxDailyCharacters, maxWeeklyCharacters: maxWeeklyCharacters,
      daysSinceFirstUse: daysSinceFirstUse, applicationCount: applicationCount,
      languageCount: languageCount, flags: flags)
  }

  func testCatalogIDsAreUniqueAndEveryCategoryHasItems() {
    let ids = CompanionCatalog.items.map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count)
    for category in CompanionItemCategory.allCases {
      XCTAssertFalse(CompanionCatalog.items(in: category).isEmpty, "\(category) is empty")
    }
    XCTAssertEqual(CompanionCatalog.item(id: CompanionCatalog.defaultColorID)?.condition, .always)
  }

  func testFreshUserIsLevelOneWithOnlyTheDefaultColor() {
    let progress = CompanionProgress(snapshot: .empty)
    XCTAssertEqual(progress.level, 1)
    XCTAssertEqual(progress.unlockedCount, 0)
    XCTAssertEqual(progress.unlockedIDs, [CompanionCatalog.defaultColorID])
    XCTAssertEqual(progress.unlockableCount, CompanionCatalog.items.count - 1)
  }

  func testEveryUnlockIsOneLevel() {
    // 200 characters earns the party hat and nothing else.
    let progress = CompanionProgress(snapshot: snapshot(totalCharacters: 200, totalDictations: 1))
    XCTAssertTrue(progress.unlockedIDs.contains("partyHat"))
    XCTAssertEqual(progress.level, 2)
    XCTAssertEqual(progress.unlockedCount, 1)
  }

  func testNextGoalsAreTheClosestLockedItems() {
    let progress = CompanionProgress(
      snapshot: snapshot(
        totalCharacters: 185_138, totalDictations: 20, streakDays: 2, longestStreakDays: 2,
        daysSinceFirstUse: 76, applicationCount: 14))

    XCTAssertEqual(progress.nextGoals.count, 3)
    let ids = progress.nextGoals.map(\.id)
    XCTAssertEqual(ids[0], "wand")  // 14 / 15 apps
    XCTAssertTrue(ids.contains("colorGold"))  // 185,138 / 200,000
    XCTAssertTrue(ids.contains("colorMidnight"))  // 76 / 100 days
    let goldGoal = progress.nextGoals.first { $0.id == "colorGold" }!
    XCTAssertEqual(goldGoal.current, 185_138)
    XCTAssertEqual(goldGoal.target, 200_000)
    XCTAssertFalse(progress.nextGoals.contains { progress.isUnlocked($0.item) })
  }

  func testFreshUserSeesTheEasiestGoalsFirst() {
    let progress = CompanionProgress(snapshot: .empty)
    // 200 characters, 10 dictations, one 150-character dictation.
    XCTAssertEqual(progress.nextGoals.map(\.id), ["partyHat", "microphone", "mask"])
  }

  func testStreakConditionCountsThePastBestRun() {
    let lost = snapshot(streakDays: 0, longestStreakDays: 7)
    XCTAssertTrue(UnlockCondition.streakDays(7).isMet(in: lost))
    XCTAssertEqual(UnlockCondition.streakDays(30).current(in: lost), 7)
  }

  func testMomentConditionsAndDescriptions() {
    L.current = .japanese
    let night = snapshot(flags: [.nightOwl])
    XCTAssertTrue(UnlockCondition.nightOwl.isMet(in: night))
    XCTAssertFalse(UnlockCondition.earlyBird.isMet(in: night))
    XCTAssertEqual(UnlockCondition.nightOwl.fraction(in: night), 1)
    XCTAssertFalse(UnlockCondition.nightOwl.showsCounter)

    let partial = snapshot(totalCharacters: 185_138)
    XCTAssertEqual(
      UnlockCondition.totalCharacters(200_000).remainingDescription(in: partial), "あと14,862文字")
    XCTAssertEqual(UnlockCondition.distinctApplications(15).description, "15個のアプリで音声入力する")
    XCTAssertEqual(UnlockCondition.dailyCharacters(2_000).description, "1日で2,000文字")
  }

  func testNewItemsAreUnlockedMinusSeen() {
    let progress = CompanionProgress(
      snapshot: snapshot(totalCharacters: 2_000, totalDictations: 10))
    XCTAssertEqual(progress.newItemIDs(seen: []), ["partyHat", "colorLeaf", "microphone"])
    XCTAssertEqual(progress.newItemIDs(seen: ["partyHat", "microphone"]), ["colorLeaf"])
  }

  func testOutfitDropsLockedItemsAndKeepsAColor() {
    var outfit = CompanionOutfit.default
    outfit.set("crown", for: .hat)
    outfit.set("colorGold", for: .color)
    outfit.set("microphone", for: .held)

    let progress = CompanionProgress(snapshot: snapshot(totalDictations: 10))
    let worn = outfit.wearingOnlyUnlocked(progress)
    XCTAssertNil(worn.hat)
    XCTAssertEqual(worn.held, "microphone")
    XCTAssertEqual(worn.color, CompanionCatalog.defaultColorID)

    outfit.set(nil, for: .color)
    XCTAssertEqual(outfit.color, CompanionCatalog.defaultColorID)
  }
}
