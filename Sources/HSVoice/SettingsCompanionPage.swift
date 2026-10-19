import SwiftUI

// MARK: - Buddy

struct CompanionSettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @ObservedObject private var usage: UsageStatsStore
  @State private var confirmingReset = false

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
    _usage = ObservedObject(wrappedValue: model.usage)
  }

  var body: some View {
    let state = CompanionState(settings: settings, usage: usage)
    SettingsPageScaffold(.companion) {
      Section {
        HStack(spacing: 16) {
          CompanionSpriteView(outfit: state.outfit, listening: model.isListening, size: 64)
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(state.name).font(.headline)
              CompanionLevelBadge(level: state.progress.level)
            }
            Text(
              L.t(
                "累計 \(UsageFormat.number(state.snapshot.totalCharacters))文字 · \(UsageFormat.number(state.snapshot.totalDictations))回 · アイテム \(state.progress.unlockedCount)/\(state.progress.unlockableCount)",
                "\(UsageFormat.number(state.snapshot.totalCharacters)) characters · \(UsageFormat.number(state.snapshot.totalDictations)) dictations · items \(state.progress.unlockedCount)/\(state.progress.unlockableCount)",
                "累计 \(UsageFormat.number(state.snapshot.totalCharacters))字 · \(UsageFormat.number(state.snapshot.totalDictations))次 · 物品 \(state.progress.unlockedCount)/\(state.progress.unlockableCount)",
                "누적 \(UsageFormat.number(state.snapshot.totalCharacters))자 · \(UsageFormat.number(state.snapshot.totalDictations))회 · 아이템 \(state.progress.unlockedCount)/\(state.progress.unlockableCount)"
              )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          Spacer()
          Button(L.t("相棒を開く", "Open buddy", "打开伙伴", "단짝 열기")) { model.showCompanion() }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
      }

      Section(L.t("相棒", "Buddy", "伙伴", "단짝")) {
        HStack {
          SettingLabel(
            title: L.t("名前", "Name", "名字", "이름"),
            detail: L.t("空欄のままでも使えます。", "Leave it blank if you like.", "留空也可以。", "비워 두어도 됩니다."))
          Spacer()
          TextField("", text: $settings.companionName, prompt: Text(CompanionState.defaultName))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
        }

        Picker(selection: $settings.dailyCharacterGoal) {
          ForEach(SettingsStore.dailyCharacterGoalChoices, id: \.self) { goal in
            Text(
              L.t(
                "\(UsageFormat.number(goal))文字", "\(UsageFormat.number(goal)) characters",
                "\(UsageFormat.number(goal))字", "\(UsageFormat.number(goal))자")
            )
            .tag(goal)
          }
        } label: {
          SettingLabel(
            title: L.t("1日の目標", "Daily goal", "每日目标", "하루 목표"),
            detail: L.t(
              "メニューバーと相棒の画面に、今日の文字数をこの目標に対して表示します。",
              "The menu bar and the buddy window show today's characters against this goal.",
              "菜单栏和伙伴窗口会按此目标显示今日字数。", "메뉴 막대와 단짝 화면에 오늘 글자 수를 이 목표 기준으로 표시합니다."))
        }

        Toggle(isOn: $settings.showCompanionInMenu) {
          SettingLabel(
            title: L.t(
              "メニューバーに相棒を表示", "Show the buddy in the menu bar", "在菜单栏显示伙伴", "메뉴 막대에 단짝 표시"),
            detail: L.t(
              "オフにしても記録は続き、設定からいつでも開けます。",
              "Usage is still counted when off; open it from here anytime.",
              "关闭后仍会继续记录，可随时从设置打开。", "꺼도 기록은 계속되며 설정에서 언제든 열 수 있습니다."))
        }
      }

      Section(L.t("記録", "Records", "记录", "기록")) {
        HStack {
          SettingLabel(
            title: L.t("使用量をリセット", "Reset usage", "重置使用量", "사용량 재설정"),
            detail: L.t(
              "文字数・回数・連続日数などを0に戻します。アイテムは解放前の状態に戻り、名前はそのまま残ります。",
              "Sets characters, dictations, streaks and the rest back to zero. Items lock again; the name stays.",
              "将字数、次数、连续天数等归零。物品恢复为未解锁状态，名字保留。",
              "글자 수·횟수·연속 일수 등을 0으로 되돌립니다. 아이템은 잠기고 이름은 남습니다."))
          Spacer()
          Button(L.t("リセット…", "Reset…", "重置…", "재설정…"), role: .destructive) {
            confirmingReset = true
          }
          .disabled(usage.record.totalDictations == 0)
        }
      }
    }
    .confirmationDialog(
      L.t("相棒の記録をリセットしますか？", "Reset the buddy's records?", "要重置伙伴的记录吗？", "단짝의 기록을 재설정할까요?"),
      isPresented: $confirmingReset, titleVisibility: .visible
    ) {
      Button(L.t("リセット", "Reset", "重置", "재설정"), role: .destructive) {
        usage.reset()
      }
      Button(L.t("キャンセル", "Cancel", "取消", "취소"), role: .cancel) {}
    } message: {
      Text(L.t("この操作は取り消せません。", "This cannot be undone.", "此操作无法撤销。", "이 작업은 되돌릴 수 없습니다."))
    }
  }
}
