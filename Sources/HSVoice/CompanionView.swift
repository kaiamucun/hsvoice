import AppKit
import SwiftUI

// MARK: - Shared pieces

/// Everything the companion UI derives from the stores, computed once per
/// render so the window, the menu row and the settings page agree.
struct CompanionState {
  let snapshot: UsageSnapshot
  let progress: CompanionProgress
  /// The outfit with locked items (after a stats reset) taken off.
  let outfit: CompanionOutfit
  let name: String
  let dailyGoal: Int
  let newItemIDs: Set<String>

  @MainActor
  init(settings: SettingsStore, usage: UsageStatsStore, now: Date = Date()) {
    snapshot = usage.snapshot(now: now)
    progress = CompanionProgress(snapshot: snapshot)
    outfit = settings.companionOutfit.wearingOnlyUnlocked(progress)
    let trimmed = settings.companionName.trimmingCharacters(in: .whitespacesAndNewlines)
    name = trimmed.isEmpty ? CompanionState.defaultName : trimmed
    dailyGoal = max(1, settings.dailyCharacterGoal)
    newItemIDs = progress.newItemIDs(seen: usage.record.seenItemIDs)
  }

  static var defaultName: String {
    L.t("相棒", "Buddy", "伙伴", "단짝")
  }

  var todayFraction: Double {
    min(1, Double(snapshot.todayCharacters) / Double(dailyGoal))
  }

  var reachedDailyGoal: Bool { snapshot.todayCharacters >= dailyGoal }

  /// One line to paste into chat: level, totals, streak.
  var shareSummary: String {
    let level = progress.level
    let total = UsageFormat.number(snapshot.totalCharacters)
    let today = UsageFormat.number(snapshot.todayCharacters)
    let items = "\(progress.unlockedCount)/\(progress.unlockableCount)"
    let streak = snapshot.streakDays
    return L.t(
      "HS Voice 相棒「\(name)」 Lv.\(level) · 累計 \(total)文字 · 今日 \(today)文字 · 連続 \(streak)日 · アイテム \(items)",
      "HS Voice buddy \"\(name)\" Lv.\(level) · \(total) characters total · \(today) today · \(streak)-day streak · items \(items)",
      "HS Voice 伙伴「\(name)」 Lv.\(level) · 累计 \(total)字 · 今日 \(today)字 · 连续 \(streak)天 · 物品 \(items)",
      "HS Voice 단짝 \"\(name)\" Lv.\(level) · 누적 \(total)자 · 오늘 \(today)자 · \(streak)일 연속 · 아이템 \(items)"
    )
  }
}

/// The yellow "Lv 24" chip.
struct CompanionLevelBadge: View {
  let level: Int
  var compact = false

  var body: some View {
    Text("Lv \(level)")
      .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .rounded))
      .foregroundStyle(Color(hex: 0x3B2A00))
      .padding(.horizontal, compact ? 6 : 8)
      .padding(.vertical, compact ? 2 : 3)
      .background(Color(hex: 0xF7C948), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
  }
}

struct CompanionNewBadge: View {
  var body: some View {
    Text("NEW")
      .font(.system(size: 9, weight: .heavy, design: .rounded))
      .foregroundStyle(.white)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color(hex: 0xE5484D), in: Capsule())
  }
}

/// Progress drawn as separate blocks, the way usage pets show it.
struct SegmentedProgressBar: View {
  let fraction: Double
  var segments = 14
  var fill = Color(hex: 0xF7C948)
  var track = Color.primary.opacity(0.12)
  var height: CGFloat = 8

  var body: some View {
    let lit = Int((min(1, max(0, fraction)) * Double(segments)).rounded(.down))
    HStack(spacing: 2) {
      ForEach(0..<segments, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
          .fill(index < lit ? fill : track)
      }
    }
    .frame(height: height)
    .accessibilityElement()
    .accessibilityValue("\(Int(fraction * 100))%")
  }
}

/// Plain bar for the goal rows and item tiles.
struct ThinProgressBar: View {
  let fraction: Double
  var fill = Color.accentColor
  var height: CGFloat = 6

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.primary.opacity(0.1))
        Capsule()
          .fill(fill)
          .frame(width: max(fraction > 0 ? height : 0, proxy.size.width * min(1, max(0, fraction))))
      }
    }
    .frame(height: height)
  }
}

// MARK: - Menu bar row

/// Compact companion row for the menu bar popover; opens the full window.
struct CompanionMenuRow: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @ObservedObject private var usage: UsageStatsStore

  init(model: AppModel, settings: SettingsStore? = nil, usage: UsageStatsStore? = nil) {
    self.model = model
    _settings = ObservedObject(wrappedValue: settings ?? model.settings)
    _usage = ObservedObject(wrappedValue: usage ?? model.usage)
  }

  var body: some View {
    let state = CompanionState(settings: settings, usage: usage)
    Button {
      model.showCompanion()
    } label: {
      HStack(spacing: 12) {
        CompanionSpriteView(outfit: state.outfit, listening: model.isListening, size: 46)

        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 6) {
            Text(state.name)
              .font(.system(size: 12.5, weight: .semibold, design: .rounded))
              .lineLimit(1)
            CompanionLevelBadge(level: state.progress.level, compact: true)
            if state.snapshot.streakDays > 0 {
              Text("\(state.snapshot.streakDays)🔥")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if !state.newItemIDs.isEmpty {
              CompanionNewBadge()
            }
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.tertiary)
          }

          HStack(spacing: 8) {
            SegmentedProgressBar(fraction: state.todayFraction, height: 6)
            Text(
              "\(UsageFormat.number(state.snapshot.todayCharacters)) / \(UsageFormat.number(state.dailyGoal))"
            )
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize()
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Color.primary.opacity(0.035),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(L.t("相棒を開く", "Open your buddy", "打开伙伴", "단짝 열기"))
  }
}

// MARK: - Window

struct CompanionView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @ObservedObject private var usage: UsageStatsStore
  @State private var category: CompanionItemCategory = .hat
  /// Unlocks that were new when the window opened; badged for this visit,
  /// then marked as seen.
  @State private var freshItemIDs: Set<String> = []
  @State private var pokeCount = 0
  @State private var copiedSummary = false

  /// The stores default to the model's; tests pass seeded ones.
  init(model: AppModel, settings: SettingsStore? = nil, usage: UsageStatsStore? = nil) {
    self.model = model
    _settings = ObservedObject(wrappedValue: settings ?? model.settings)
    _usage = ObservedObject(wrappedValue: usage ?? model.usage)
  }

  var body: some View {
    let state = CompanionState(settings: settings, usage: usage)
    VStack(spacing: 0) {
      topBar(state)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)

      Divider()

      HStack(alignment: .top, spacing: 18) {
        VStack(alignment: .leading, spacing: 14) {
          levelCard(state)
          stage(state)
            .frame(maxHeight: .infinity)
          wearingLine(state)
        }
        .frame(width: 350)
        .frame(maxHeight: .infinity)

        wardrobe(state)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .padding(20)
    }
    .frame(minWidth: 820, minHeight: 600)
    .onAppear {
      let fresh = state.newItemIDs
      freshItemIDs = fresh
      usage.markItemsSeen(fresh)
      if let firstFresh = fresh.first, let item = CompanionCatalog.item(id: firstFresh) {
        category = item.category
      }
    }
  }

  // MARK: Top bar

  private func topBar(_ state: CompanionState) -> some View {
    HStack(spacing: 14) {
      TextField(
        L.t("ペットに名前をつける", "Name your pet", "给宠物起个名字", "펫에게 이름 짓기"),
        text: $settings.companionName
      )
      .textFieldStyle(.plain)
      .font(.system(size: 20, weight: .bold, design: .rounded))
      .frame(maxWidth: 300)

      Text(
        L.t(
          "\(UsageFormat.number(state.snapshot.totalCharacters))文字",
          "\(UsageFormat.number(state.snapshot.totalCharacters)) characters",
          "\(UsageFormat.number(state.snapshot.totalCharacters))字",
          "\(UsageFormat.number(state.snapshot.totalCharacters))자")
      )
      .font(.system(size: 14, weight: .medium, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(.secondary)

      Spacer()

      Button {
        model.showSettings(page: .companion)
      } label: {
        Label(L.t("設定", "Settings", "设置", "설정"), systemImage: "gearshape")
      }

      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.shareSummary, forType: .string)
        copiedSummary = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copiedSummary = false }
      } label: {
        Label(
          copiedSummary
            ? L.t("コピーしました", "Copied", "已复制", "복사했습니다")
            : L.t("共有", "Share", "共享", "공유"),
          systemImage: copiedSummary ? "checkmark" : "square.and.arrow.up")
      }
      .help(
        L.t("レベルと使用量のまとめをコピー", "Copy a summary of level and usage", "复制等级和使用量摘要", "레벨과 사용량 요약 복사"))
    }
  }

  // MARK: Level card

  private func levelCard(_ state: CompanionState) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(
          L.t(
            "レベル\(state.progress.level)", "Level \(state.progress.level)",
            "等级\(state.progress.level)", "레벨 \(state.progress.level)")
        )
        .font(.system(size: 22, weight: .heavy, design: .rounded))
        Text(
          L.t(
            "· \(state.progress.unlockableCount)個中\(state.progress.unlockedCount)個を入手",
            "· \(state.progress.unlockedCount) of \(state.progress.unlockableCount) items",
            "· 已获得\(state.progress.unlockableCount)个中的\(state.progress.unlockedCount)个",
            "· \(state.progress.unlockableCount)개 중 \(state.progress.unlockedCount)개 획득")
        )
        .font(.system(size: 12.5, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        Spacer()
        if state.snapshot.streakDays > 0 {
          Text(
            L.t(
              "\(state.snapshot.streakDays)日連続 🔥", "\(state.snapshot.streakDays)-day streak 🔥",
              "连续\(state.snapshot.streakDays)天 🔥", "\(state.snapshot.streakDays)일 연속 🔥")
          )
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(.orange)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(L.t("今日", "Today", "今天", "오늘"))
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
          Text(UsageFormat.number(state.snapshot.todayCharacters))
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .monospacedDigit()
          Text(
            L.t(
              "/ \(UsageFormat.number(state.dailyGoal)) 文字",
              "/ \(UsageFormat.number(state.dailyGoal)) characters",
              "/ \(UsageFormat.number(state.dailyGoal)) 字",
              "/ \(UsageFormat.number(state.dailyGoal)) 자")
          )
          .font(.system(size: 12.5, weight: .medium, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.secondary)
          Spacer()
          if state.reachedDailyGoal {
            Label(L.t("達成", "Done", "达成", "달성"), systemImage: "checkmark.seal.fill")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(.green)
          }
        }
        SegmentedProgressBar(fraction: state.todayFraction)
      }

      Divider()

      VStack(alignment: .leading, spacing: 10) {
        Text(L.t("次の目標", "Next up", "下一个目标", "다음 목표"))
          .font(.system(size: 11.5, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
        if state.progress.nextGoals.isEmpty {
          Text(
            L.t("すべてのアイテムを入手しました！", "You've collected everything!", "已获得全部物品！", "모든 아이템을 획득했습니다!")
          )
          .font(.callout)
        }
        ForEach(state.progress.nextGoals) { goal in
          goalRow(goal, state: state)
        }
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    }
  }

  private func goalRow(_ goal: CompanionGoal, state: CompanionState) -> some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(Color.primary.opacity(0.06))
        CompanionItemThumbnail(item: goal.item, size: 26)
          .blur(radius: goal.item.hidden ? 3 : 0)
          .saturation(goal.item.hidden ? 0 : 0.6)
          .opacity(goal.item.hidden ? 0.5 : 0.8)
      }
      .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline) {
          Text(goal.item.condition.description)
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .lineLimit(1)
          Spacer(minLength: 6)
          if goal.item.condition.showsCounter {
            Text("\(UsageFormat.number(goal.current)) / \(UsageFormat.number(goal.target))")
              .font(.system(size: 11.5, weight: .medium, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        ThinProgressBar(fraction: goal.fraction)
      }
    }
  }

  // MARK: Stage

  private func stage(_ state: CompanionState) -> some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color(hex: 0xDDEFFF), Color(hex: 0xF2F8FF)],
            startPoint: .top, endPoint: .bottom))

      // Floor: faint vertical stripes, like a pixel-art platform.
      VStack {
        Spacer()
        HStack(spacing: 0) {
          ForEach(0..<24, id: \.self) { index in
            Rectangle()
              .fill(index.isMultiple(of: 2) ? Color(hex: 0xC9DDF2) : Color(hex: 0xD9E8F7))
          }
        }
        .frame(height: 44)
      }
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

      VStack {
        Spacer()
        CompanionSpriteView(outfit: state.outfit, listening: model.isListening, size: 176)
          .offset(y: 12)
          .scaleEffect(pokeCount.isMultiple(of: 2) ? 1 : 0.92, anchor: .bottom)
          .animation(.spring(response: 0.25, dampingFraction: 0.45), value: pokeCount)
          .onTapGesture { pokeCount += 1 }
        Spacer().frame(height: 26)
      }
      .frame(maxWidth: .infinity)

      speechBubble(bubbleMessage(state))
        .padding(14)
    }
    .frame(minHeight: 230)
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      L.t(
        "\(state.name)、レベル\(state.progress.level)", "\(state.name), level \(state.progress.level)",
        "\(state.name)，等级\(state.progress.level)", "\(state.name), 레벨 \(state.progress.level)"))
  }

  private func speechBubble(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 12.5, weight: .semibold, design: .rounded))
      .foregroundStyle(Color(hex: 0x1E1F2B))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(Color(hex: 0x1E1F2B), lineWidth: 1.5)
      }
  }

  private func bubbleMessage(_ state: CompanionState) -> String {
    if model.isListening {
      return L.t("聞いてるよ…", "Listening…", "我在听…", "듣고 있어…")
    }
    if !freshItemIDs.isEmpty {
      return L.t(
        "新しいアイテムを入手！着てみよう。", "New item unlocked! Try it on.", "获得新物品！试试看。", "새 아이템 획득! 입어 보자.")
    }
    if state.reachedDailyGoal {
      return L.t("今日の目標達成！すごい！", "Daily goal reached! Amazing!", "今日目标达成！太棒了！", "오늘 목표 달성! 대단해!")
    }
    if state.snapshot.streakDays >= 3 {
      return L.t(
        "\(state.snapshot.streakDays)日連続！その調子。",
        "\(state.snapshot.streakDays) days in a row! Keep it up.",
        "连续\(state.snapshot.streakDays)天！继续保持。", "\(state.snapshot.streakDays)일 연속! 그 기세로.")
    }
    if state.snapshot.totalDictations == 0 {
      return L.t(
        "はじめまして！話しかけてね。", "Nice to meet you! Talk to me.", "初次见面！跟我说话吧。", "처음 뵙겠습니다! 말을 걸어 줘.")
    }
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<11:
      return L.t("おはよう！今日も話そう。", "Morning! Let's talk today.", "早上好！今天也来说话吧。", "좋은 아침! 오늘도 이야기하자.")
    case 11..<18: return L.t("こんにちは！", "Hello!", "你好！", "안녕!")
    default: return L.t("おつかれさま。", "Good work today.", "辛苦了。", "수고했어.")
    }
  }

  private func wearingLine(_ state: CompanionState) -> some View {
    let worn = [CompanionItemCategory.hat, .face, .held, .color].compactMap { category -> String? in
      guard let id = state.outfit.itemID(for: category),
        let item = CompanionCatalog.item(id: id), item.countsTowardLevel
      else { return nil }
      return item.name
    }
    return HStack(spacing: 6) {
      Text(L.t("着用中:", "Wearing:", "穿戴中:", "착용 중:"))
        .foregroundStyle(.secondary)
      Text(worn.isEmpty ? L.t("なし", "Nothing", "无", "없음") : worn.joined(separator: " · "))
        .fontWeight(.semibold)
        .lineLimit(1)
    }
    .font(.system(size: 12, design: .rounded))
  }

  // MARK: Wardrobe

  private func wardrobe(_ state: CompanionState) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 4) {
        ForEach(CompanionItemCategory.allCases) { tab in
          let hasFresh = CompanionCatalog.items(in: tab).contains { freshItemIDs.contains($0.id) }
          Button {
            category = tab
          } label: {
            HStack(spacing: 5) {
              Text(tab.title)
              if hasFresh {
                Circle().fill(Color(hex: 0xE5484D)).frame(width: 6, height: 6)
              }
            }
            .font(.system(size: 13, weight: category == tab ? .bold : .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
              category == tab ? Color.primary.opacity(0.08) : Color.clear,
              in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        Spacer()
        Text(
          L.t(
            "\(unlockedCount(in: category, state: state))/\(CompanionCatalog.items(in: category).filter(\.countsTowardLevel).count)",
            "\(unlockedCount(in: category, state: state))/\(CompanionCatalog.items(in: category).filter(\.countsTowardLevel).count)",
            "\(unlockedCount(in: category, state: state))/\(CompanionCatalog.items(in: category).filter(\.countsTowardLevel).count)",
            "\(unlockedCount(in: category, state: state))/\(CompanionCatalog.items(in: category).filter(\.countsTowardLevel).count)"
          )
        )
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.secondary)
      }

      ScrollView {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 128, maximum: 180), spacing: 12)], spacing: 12
        ) {
          if category.allowsNone {
            noneTile(state)
          }
          ForEach(CompanionCatalog.items(in: category)) { item in
            itemTile(item, state: state)
          }
        }
        .padding(.bottom, 8)
      }
    }
  }

  private func unlockedCount(in category: CompanionItemCategory, state: CompanionState) -> Int {
    CompanionCatalog.items(in: category).filter {
      $0.countsTowardLevel && state.progress.isUnlocked($0)
    }.count
  }

  private func noneTile(_ state: CompanionState) -> some View {
    let isWorn = state.outfit.itemID(for: category) == nil
    var bare = CompanionOutfit.default
    bare.color = state.outfit.color
    return CompanionItemTile(
      title: category.noneTitle,
      caption: L.t("デフォルト", "Default", "默认", "기본"),
      isUnlocked: true,
      isWorn: isWorn,
      isFresh: false,
      progressFraction: nil
    ) {
      CompanionSpriteView(outfit: bare, animated: false, size: 60)
    } action: {
      settings.wearCompanionItem(nil, for: category)
    }
  }

  private func itemTile(_ item: CompanionItem, state: CompanionState) -> some View {
    let unlocked = state.progress.isUnlocked(item)
    let worn = state.outfit.itemID(for: item.category) == item.id
    let fraction = item.condition.fraction(in: state.snapshot)
    let caption: String
    if unlocked {
      caption = item.condition.description
    } else if item.condition.showsCounter, fraction > 0 {
      caption = item.condition.remainingDescription(in: state.snapshot)
    } else {
      caption = item.condition.description
    }
    return CompanionItemTile(
      title: unlocked || !item.hidden ? item.name : "？？？",
      caption: caption,
      isUnlocked: unlocked,
      isWorn: worn,
      isFresh: freshItemIDs.contains(item.id),
      progressFraction: !unlocked && item.condition.showsCounter && fraction > 0 ? fraction : nil
    ) {
      CompanionItemThumbnail(item: item, size: 56)
        .blur(radius: !unlocked && item.hidden ? 5 : 0)
        .saturation(unlocked ? 1 : 0)
        .opacity(unlocked ? 1 : 0.45)
    } action: {
      guard unlocked else { return }
      if worn {
        if item.category.allowsNone {
          settings.wearCompanionItem(nil, for: item.category)
        }
      } else {
        settings.wearCompanionItem(item.id, for: item.category)
      }
    }
  }
}

/// One square in the wardrobe grid.
private struct CompanionItemTile<Thumbnail: View>: View {
  let title: String
  let caption: String
  let isUnlocked: Bool
  let isWorn: Bool
  let isFresh: Bool
  let progressFraction: Double?
  @ViewBuilder let thumbnail: () -> Thumbnail
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack(alignment: .topTrailing) {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isUnlocked ? Color.primary.opacity(0.05) : Color.primary.opacity(0.03))
            .overlay {
              if !isUnlocked {
                LockedStripes()
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
            }
          thumbnail()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          if isUnlocked {
            Image(systemName: "checkmark.square.fill")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white, isWorn ? Color.accentColor : Color.green)
              .padding(6)
          }
          if isFresh {
            CompanionNewBadge()
              .padding(6)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(height: 86)

        Text(title)
          .font(.system(size: 12.5, weight: .bold, design: .rounded))
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .frame(minHeight: 30, alignment: .top)

        VStack(spacing: 4) {
          if let progressFraction {
            ThinProgressBar(fraction: progressFraction, height: 5)
              .padding(.horizontal, 6)
          }
          Text(caption)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .frame(minHeight: 30, alignment: .top)
      }
      .padding(10)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(
            isWorn ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isWorn ? 2 : 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .opacity(isUnlocked ? 1 : 0.85)
    .accessibilityLabel("\(title), \(caption)")
    .accessibilityAddTraits(isWorn ? .isSelected : [])
  }
}

/// Diagonal hatching behind locked items.
private struct LockedStripes: View {
  var body: some View {
    Canvas { context, size in
      let step: CGFloat = 9
      var x: CGFloat = -size.height
      while x < size.width {
        var path = Path()
        path.move(to: CGPoint(x: x, y: size.height))
        path.addLine(to: CGPoint(x: x + size.height, y: 0))
        context.stroke(path, with: .color(Color.primary.opacity(0.06)), lineWidth: 4)
        x += step
      }
    }
  }
}
