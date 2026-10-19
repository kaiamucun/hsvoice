import Foundation

/// What a companion item is worn as.
enum CompanionItemCategory: String, CaseIterable, Identifiable, Codable {
  case hat
  case face
  case held
  case color

  var id: String { rawValue }

  var title: String {
    switch self {
    case .hat: return L.t("帽子", "Hats", "帽子", "모자")
    case .face: return L.t("顔", "Face", "脸部", "얼굴")
    case .held: return L.t("手持ち", "Held", "手持", "소지품")
    case .color: return L.t("カラー", "Colors", "颜色", "색상")
    }
  }

  /// Hats, face and held items can be taken off; the body always has a color.
  var allowsNone: Bool { self != .color }

  var noneTitle: String {
    switch self {
    case .hat: return L.t("帽子なし", "No hat", "无帽子", "모자 없음")
    case .face: return L.t("なし", "None", "无", "없음")
    case .held: return L.t("なし", "None", "无", "없음")
    case .color: return L.t("アクアブルー", "Aqua blue", "水蓝", "아쿠아 블루")
    }
  }
}

/// How an item is earned. Each case knows its target and how to read the
/// current value out of a `UsageSnapshot`, so the UI can show "14 / 15".
enum UnlockCondition: Equatable {
  case always
  case totalCharacters(Int)
  case totalDictations(Int)
  case distinctApplications(Int)
  case dailyCharacters(Int)
  case weeklyCharacters(Int)
  case streakDays(Int)
  case daysSinceFirstUse(Int)
  case activeDays(Int)
  case longestDictation(Int)
  case languages(Int)
  case nightOwl
  case earlyBird
  case weekend

  var target: Int {
    switch self {
    case .always: return 0
    case .totalCharacters(let n), .totalDictations(let n), .distinctApplications(let n),
      .dailyCharacters(let n), .weeklyCharacters(let n), .streakDays(let n),
      .daysSinceFirstUse(let n), .activeDays(let n), .longestDictation(let n), .languages(let n):
      return n
    case .nightOwl, .earlyBird, .weekend: return 1
    }
  }

  func current(in snapshot: UsageSnapshot) -> Int {
    switch self {
    case .always: return 0
    case .totalCharacters: return snapshot.totalCharacters
    case .totalDictations: return snapshot.totalDictations
    case .distinctApplications: return snapshot.applicationCount
    case .dailyCharacters: return snapshot.maxDailyCharacters
    case .weeklyCharacters: return snapshot.maxWeeklyCharacters
    case .streakDays: return max(snapshot.streakDays, snapshot.longestStreakDays)
    case .daysSinceFirstUse: return snapshot.daysSinceFirstUse
    case .activeDays: return snapshot.activeDays
    case .longestDictation: return snapshot.longestDictation
    case .languages: return snapshot.languageCount
    case .nightOwl: return snapshot.flags.contains(.nightOwl) ? 1 : 0
    case .earlyBird: return snapshot.flags.contains(.earlyBird) ? 1 : 0
    case .weekend: return snapshot.flags.contains(.weekend) ? 1 : 0
    }
  }

  func isMet(in snapshot: UsageSnapshot) -> Bool {
    if case .always = self { return true }
    return current(in: snapshot) >= target
  }

  /// 0…1, clamped. Boolean conditions jump straight from 0 to 1.
  func fraction(in snapshot: UsageSnapshot) -> Double {
    guard target > 0 else { return 1 }
    return min(1, Double(current(in: snapshot)) / Double(target))
  }

  /// Rough cost in characters-of-dictation, so goals with no progress yet can
  /// still be ordered easiest-first ("200 characters" before "30 days").
  var effortEstimate: Int {
    switch self {
    case .always: return 0
    case .totalCharacters(let n), .weeklyCharacters(let n): return n
    case .dailyCharacters(let n): return n * 2
    case .longestDictation(let n): return n * 8
    case .totalDictations(let n): return n * 80
    case .distinctApplications(let n): return n * 300
    case .streakDays(let n), .daysSinceFirstUse(let n), .activeDays(let n): return n * 800
    case .languages(let n): return n * 2_000
    case .nightOwl, .earlyBird, .weekend: return 3_000
    }
  }

  /// Whether "current / target" is meaningful to show (counts, not moments).
  var showsCounter: Bool {
    switch self {
    case .always, .nightOwl, .earlyBird, .weekend: return false
    default: return true
    }
  }

  /// The condition as a sentence: "15個のアプリで音声入力する".
  var description: String {
    let n = UsageFormat.number(target)
    switch self {
    case .always:
      return L.t("デフォルト", "Default", "默认", "기본")
    case .totalCharacters:
      return L.t("累計\(n)文字", "\(n) characters in total", "累计\(n)字", "누적 \(n)자")
    case .totalDictations:
      return L.t("\(n)回音声入力する", "Dictate \(n) times", "语音输入\(n)次", "\(n)회 음성 입력")
    case .distinctApplications:
      return L.t(
        "\(n)個のアプリで音声入力する", "Dictate into \(n) apps", "在\(n)个应用中语音输入",
        "\(n)개 앱에서 음성 입력")
    case .dailyCharacters:
      return L.t("1日で\(n)文字", "\(n) characters in one day", "一天内\(n)字", "하루에 \(n)자")
    case .weeklyCharacters:
      return L.t("1週間で\(n)文字", "\(n) characters in one week", "一周内\(n)字", "일주일에 \(n)자")
    case .streakDays:
      return L.t("\(n)日連続で音声入力する", "Dictate \(n) days in a row", "连续\(n)天语音输入", "\(n)일 연속 음성 입력")
    case .daysSinceFirstUse:
      return L.t("HS Voiceと\(n)日", "\(n) days with HS Voice", "与HS Voice相伴\(n)天", "HS Voice와 \(n)일")
    case .activeDays:
      return L.t("\(n)日使う", "Use it on \(n) days", "使用\(n)天", "\(n)일 사용")
    case .longestDictation:
      return L.t("一度に\(n)文字", "\(n) characters in one go", "一次\(n)字", "한 번에 \(n)자")
    case .languages:
      return L.t("\(n)言語で音声入力する", "Dictate in \(n) languages", "用\(n)种语言语音输入", "\(n)개 언어로 음성 입력")
    case .nightOwl:
      return L.t("深夜0時以降に音声入力する", "Dictate after midnight", "深夜0点后语音输入", "자정 이후에 음성 입력")
    case .earlyBird:
      return L.t("朝8時前に音声入力する", "Dictate before 8 am", "早上8点前语音输入", "아침 8시 전에 음성 입력")
    case .weekend:
      return L.t("週末に音声入力する", "Dictate on a weekend", "周末语音输入", "주말에 음성 입력")
    }
  }

  /// What is still missing: "あと14,862文字". Falls back to the description
  /// for conditions that are moments rather than counts.
  func remainingDescription(in snapshot: UsageSnapshot) -> String {
    let remaining = UsageFormat.number(max(0, target - current(in: snapshot)))
    switch self {
    case .totalCharacters, .dailyCharacters, .weeklyCharacters, .longestDictation:
      return L.t(
        "あと\(remaining)文字", "\(remaining) characters to go", "还差\(remaining)字", "\(remaining)자 남음")
    case .totalDictations:
      return L.t(
        "あと\(remaining)回", "\(remaining) dictations to go", "还差\(remaining)次", "\(remaining)회 남음")
    case .distinctApplications:
      return L.t(
        "あと\(remaining)個のアプリ", "\(remaining) more apps", "还差\(remaining)个应用", "앱 \(remaining)개 남음")
    case .streakDays, .daysSinceFirstUse, .activeDays:
      return L.t(
        "あと\(remaining)日", "\(remaining) days to go", "还差\(remaining)天", "\(remaining)일 남음")
    case .languages:
      return L.t(
        "あと\(remaining)言語", "\(remaining) more languages", "还差\(remaining)种语言",
        "언어 \(remaining)개 남음")
    case .always, .nightOwl, .earlyBird, .weekend:
      return description
    }
  }
}

struct CompanionItem: Identifiable, Equatable {
  let id: String
  let category: CompanionItemCategory
  let condition: UnlockCondition
  /// Name and look stay secret until unlocked; the condition is still shown.
  let hidden: Bool
  private let names: (String, String, String, String)

  init(
    _ id: String, _ category: CompanionItemCategory, _ condition: UnlockCondition,
    hidden: Bool = false, ja: String, en: String, zh: String, ko: String
  ) {
    self.id = id
    self.category = category
    self.condition = condition
    self.hidden = hidden
    self.names = (ja, en, zh, ko)
  }

  var name: String { L.t(names.0, names.1, names.2, names.3) }

  /// Default (always unlocked) items are choices, not rewards: they count
  /// toward neither the level nor the "N of M" tally.
  var countsTowardLevel: Bool { condition != .always }

  static func == (lhs: CompanionItem, rhs: CompanionItem) -> Bool { lhs.id == rhs.id }
}

/// Every item the companion can wear, with how to earn it. Thresholds start
/// low so the first unlock lands within a few dictations and climb to the
/// hundreds of thousands of characters for long-term goals.
enum CompanionCatalog {
  static let defaultColorID = "colorAqua"

  static let items: [CompanionItem] = [
    // Hats
    .init(
      "partyHat", .hat, .totalCharacters(200), ja: "パーティーハット", en: "Party hat", zh: "派对帽",
      ko: "파티 모자"),
    .init(
      "beanie", .hat, .totalCharacters(30_000), ja: "ニット帽", en: "Beanie", zh: "针织帽", ko: "니트 모자"),
    .init(
      "cowboyHat", .hat, .daysSinceFirstUse(50), ja: "カウボーイハット", en: "Cowboy hat", zh: "牛仔帽",
      ko: "카우보이 모자"),
    .init(
      "headphones", .hat, .dailyCharacters(2_000), ja: "ヘッドホン", en: "Headphones", zh: "耳机",
      ko: "헤드폰"),
    .init(
      "flameBand", .hat, .streakDays(7), ja: "炎のハチマキ", en: "Flame headband", zh: "火焰头带",
      ko: "불꽃 머리띠"),
    .init(
      "nightcap", .hat, .nightOwl, hidden: true, ja: "ナイトキャップ", en: "Nightcap", zh: "睡帽", ko: "나이트캡"
    ),
    .init(
      "chefHat", .hat, .earlyBird, hidden: true, ja: "コック帽", en: "Chef's hat", zh: "厨师帽",
      ko: "요리사 모자"),
    .init("strawHat", .hat, .weekend, ja: "麦わら帽子", en: "Straw hat", zh: "草帽", ko: "밀짚모자"),
    .init(
      "hardHat", .hat, .totalDictations(500), ja: "ヘルメット", en: "Hard hat", zh: "安全帽", ko: "안전모"),
    .init(
      "wizardHat", .hat, .weeklyCharacters(30_000), ja: "魔法使いの帽子", en: "Wizard hat", zh: "魔法师帽",
      ko: "마법사 모자"),
    .init(
      "graduationCap", .hat, .languages(3), ja: "角帽", en: "Graduation cap", zh: "学士帽", ko: "학사모"),
    .init(
      "halo", .hat, .totalCharacters(100_000), ja: "天使の輪", en: "Halo", zh: "天使光环", ko: "천사의 고리"),
    .init(
      "topHat", .hat, .totalCharacters(150_000), ja: "シルクハット", en: "Top hat", zh: "礼帽", ko: "실크해트"),
    .init("crown", .hat, .totalCharacters(500_000), ja: "王冠", en: "Crown", zh: "王冠", ko: "왕관"),

    // Face
    .init("glasses", .face, .totalDictations(50), ja: "メガネ", en: "Glasses", zh: "眼镜", ko: "안경"),
    .init("eyepatch", .face, .streakDays(3), ja: "眼帯", en: "Eye patch", zh: "眼罩", ko: "안대"),
    .init("mustache", .face, .daysSinceFirstUse(20), ja: "ヒゲ", en: "Mustache", zh: "胡子", ko: "콧수염"),
    .init("mask", .face, .longestDictation(150), ja: "マスク", en: "Face mask", zh: "口罩", ko: "마스크"),
    .init(
      "monocle", .face, .totalCharacters(50_000), ja: "モノクル", en: "Monocle", zh: "单片眼镜", ko: "모노클"),
    .init(
      "sunglasses", .face, .dailyCharacters(5_000), ja: "サングラス", en: "Sunglasses", zh: "墨镜",
      ko: "선글라스"),
    .init("starEyes", .face, .activeDays(30), ja: "星の目", en: "Star eyes", zh: "星星眼", ko: "별 눈"),

    // Held
    .init(
      "microphone", .held, .totalDictations(10), ja: "マイク", en: "Microphone", zh: "麦克风", ko: "마이크"),
    .init("pencil", .held, .totalCharacters(10_000), ja: "えんぴつ", en: "Pencil", zh: "铅笔", ko: "연필"),
    .init("coffee", .held, .activeDays(10), ja: "コーヒー", en: "Coffee", zh: "咖啡", ko: "커피"),
    .init("flag", .held, .distinctApplications(5), ja: "旗", en: "Flag", zh: "旗帜", ko: "깃발"),
    .init("book", .held, .languages(2), ja: "本", en: "Book", zh: "书", ko: "책"),
    .init(
      "umbrella", .held, .weeklyCharacters(10_000), ja: "傘", en: "Umbrella", zh: "雨伞", ko: "우산"),
    .init(
      "wand", .held, .distinctApplications(15), ja: "星のステッキ", en: "Star wand", zh: "星星魔杖",
      ko: "별 지팡이"),
    .init("trophy", .held, .streakDays(30), ja: "トロフィー", en: "Trophy", zh: "奖杯", ko: "트로피"),

    // Colors
    .init(defaultColorID, .color, .always, ja: "アクアブルー", en: "Aqua blue", zh: "水蓝", ko: "아쿠아 블루"),
    .init(
      "colorLeaf", .color, .totalCharacters(2_000), ja: "リーフグリーン", en: "Leaf green", zh: "叶绿",
      ko: "리프 그린"),
    .init(
      "colorSakura", .color, .totalDictations(100), ja: "さくらピンク", en: "Sakura pink", zh: "樱花粉",
      ko: "벚꽃 핑크"),
    .init(
      "colorLavender", .color, .dailyCharacters(3_000), ja: "ラベンダー", en: "Lavender", zh: "薰衣草",
      ko: "라벤더"),
    .init(
      "colorSunset", .color, .streakDays(14), ja: "サンセットオレンジ", en: "Sunset orange", zh: "日落橙",
      ko: "선셋 오렌지"),
    .init(
      "colorRuby", .color, .longestDictation(300), ja: "ルビーレッド", en: "Ruby red", zh: "宝石红",
      ko: "루비 레드"),
    .init(
      "colorMidnight", .color, .daysSinceFirstUse(100), ja: "ミッドナイト", en: "Midnight", zh: "午夜蓝",
      ko: "미드나이트"),
    .init(
      "colorSnow", .color, .totalDictations(1_000), ja: "スノーホワイト", en: "Snow white", zh: "雪白",
      ko: "스노 화이트"),
    .init(
      "colorGold", .color, .totalCharacters(200_000), ja: "ゴールド", en: "Gold", zh: "金色", ko: "골드"),
  ]

  static func item(id: String) -> CompanionItem? {
    items.first { $0.id == id }
  }

  static func items(in category: CompanionItemCategory) -> [CompanionItem] {
    items.filter { $0.category == category }
  }

  /// Items that can be earned (everything but the defaults).
  static var unlockableCount: Int {
    items.filter(\.countsTowardLevel).count
  }
}

/// One item the user is working toward, with its progress.
struct CompanionGoal: Identifiable, Equatable {
  let item: CompanionItem
  let current: Int
  let target: Int
  let fraction: Double

  var id: String { item.id }
}

/// The companion's level and collection, derived from a usage snapshot.
struct CompanionProgress: Equatable {
  let unlockedIDs: Set<String>
  /// Level = 1 + items earned. Every unlock is a level-up.
  let level: Int
  let unlockedCount: Int
  let unlockableCount: Int
  /// Locked items closest to unlocking, best progress first.
  let nextGoals: [CompanionGoal]

  init(snapshot: UsageSnapshot, goalCount: Int = 3) {
    var unlocked: Set<String> = []
    var goals: [(goal: CompanionGoal, catalogIndex: Int)] = []
    for (index, item) in CompanionCatalog.items.enumerated() {
      if item.condition.isMet(in: snapshot) {
        unlocked.insert(item.id)
      } else {
        goals.append(
          (
            CompanionGoal(
              item: item,
              current: item.condition.current(in: snapshot),
              target: item.condition.target,
              fraction: item.condition.fraction(in: snapshot)),
            index
          ))
      }
    }
    unlockedIDs = unlocked
    unlockedCount =
      CompanionCatalog.items.filter { $0.countsTowardLevel && unlocked.contains($0.id) }.count
    unlockableCount = CompanionCatalog.unlockableCount
    level = 1 + unlockedCount
    // Most progress first; among untouched goals the cheapest; then catalog
    // order so the list never reshuffles between renders.
    nextGoals = Array(
      goals.sorted { lhs, rhs in
        if lhs.goal.fraction != rhs.goal.fraction { return lhs.goal.fraction > rhs.goal.fraction }
        let lhsEffort = lhs.goal.item.condition.effortEstimate
        let rhsEffort = rhs.goal.item.condition.effortEstimate
        if lhsEffort != rhsEffort { return lhsEffort < rhsEffort }
        return lhs.catalogIndex < rhs.catalogIndex
      }.prefix(goalCount).map(\.goal))
  }

  func isUnlocked(_ item: CompanionItem) -> Bool {
    unlockedIDs.contains(item.id)
  }

  /// Unlocked items the user has not looked at yet.
  func newItemIDs(seen: Set<String>) -> Set<String> {
    Set(CompanionCatalog.items.filter { $0.countsTowardLevel }.map(\.id))
      .intersection(unlockedIDs).subtracting(seen)
  }
}

/// What the companion is wearing. Stored in settings; an item that is no
/// longer unlocked (after a stats reset) simply isn't drawn.
struct CompanionOutfit: Codable, Equatable {
  var hat: String?
  var face: String?
  var held: String?
  var color: String = CompanionCatalog.defaultColorID

  static let `default` = CompanionOutfit()

  func itemID(for category: CompanionItemCategory) -> String? {
    switch category {
    case .hat: return hat
    case .face: return face
    case .held: return held
    case .color: return color
    }
  }

  mutating func set(_ itemID: String?, for category: CompanionItemCategory) {
    switch category {
    case .hat: hat = itemID
    case .face: face = itemID
    case .held: held = itemID
    case .color: color = itemID ?? CompanionCatalog.defaultColorID
    }
  }

  /// The outfit with every locked item taken off.
  func wearingOnlyUnlocked(_ progress: CompanionProgress) -> CompanionOutfit {
    var resolved = self
    for category in CompanionItemCategory.allCases {
      guard let id = resolved.itemID(for: category) else { continue }
      if !progress.unlockedIDs.contains(id) {
        resolved.set(nil, for: category)
      }
    }
    return resolved
  }
}
