import AppKit
import SwiftUI

struct HistoryView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var history: HistoryStore
  // Observed so a display-language switch repaints this window immediately.
  @ObservedObject private var settings = SettingsStore.shared
  @State private var searchText = ""

  init(model: AppModel) {
    self.model = model
    _history = ObservedObject(wrappedValue: model.history)
  }

  private var filteredEntries: [HistoryEntry] {
    guard !searchText.isEmpty else { return history.entries }
    return history.entries.filter {
      $0.text.localizedCaseInsensitiveContains(searchText)
        || ($0.applicationName?.localizedCaseInsensitiveContains(searchText) ?? false)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(L.t("音声入力の履歴", "Dictation History", "语音输入历史", "음성 입력 기록"))
            .font(.title2.bold())
          Text(L.t("このMacだけに保存されたテキストです", "Text stored only on this Mac", "仅保存在这台Mac上的文本", "이 Mac에만 저장된 텍스트입니다"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if !history.entries.isEmpty {
          Button(L.t("すべて削除", "Delete all", "全部删除", "모두 삭제"), role: .destructive) {
            history.clear()
          }
        }
      }
      .padding(20)

      Divider()

      if history.entries.isEmpty {
        EmptyStatePlaceholder(
          title: L.t("履歴はありません", "No history yet", "暂无历史", "기록이 없습니다"),
          systemImage: "clock",
          description: model.settings.keepHistory
            ? L.t("音声入力するとここに表示されます。", "Dictations will appear here.", "语音输入后将显示在这里。", "음성 입력하면 여기에 표시됩니다.")
            : L.t(
              "設定で履歴保存を有効にすると、テキストのみ記録します。", "Enable history in settings to record text only.",
              "在设置中启用历史保存后，将仅记录文本。", "설정에서 기록 저장을 켜면 텍스트만 기록합니다.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(filteredEntries) { entry in
          HistoryRow(entry: entry) {
            model.insertText(entry.text)
          } onCopy: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.text, forType: .string)
          } onDelete: {
            history.remove(id: entry.id)
          }
        }
        .listStyle(.inset)
        .searchable(
          text: $searchText,
          prompt: L.t("テキストまたはアプリ名を検索", "Search text or app name", "搜索文本或应用名", "텍스트 또는 앱 이름 검색"))
      }
    }
    .frame(minWidth: 620, minHeight: 420)
  }
}

private struct HistoryRow: View {
  let entry: HistoryEntry
  let onInsert: () -> Void
  let onCopy: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(entry.text)
        .font(.system(size: 13))
        .textSelection(.enabled)
        .lineLimit(5)

      HStack(spacing: 8) {
        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
        if let appName = entry.applicationName {
          Text("•")
          Text(appName)
        }
        Text("•")
        Text(entry.localeIdentifier)
        Spacer()
        Button(action: onInsert) {
          Image(systemName: "text.cursor")
        }
        .buttonStyle(.borderless)
        .help(
          L.t(
            "直前に使っていたアプリのカーソル位置へ入力", "Type at the cursor in the app you were using",
            "输入到之前所用应用的光标位置", "직전에 사용하던 앱의 커서 위치에 입력"))
        Button(action: onCopy) {
          Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .help(L.t("コピー", "Copy", "复制", "복사"))
        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help(L.t("削除", "Delete", "删除", "삭제"))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
  }
}
