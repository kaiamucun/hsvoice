import AppKit
import SwiftUI

struct HistoryView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var history: HistoryStore
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
          Text("音声入力の履歴")
            .font(.title2.bold())
          Text("このMacだけに保存されたテキストです")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if !history.entries.isEmpty {
          Button("すべて削除", role: .destructive) {
            history.clear()
          }
        }
      }
      .padding(20)

      Divider()

      if history.entries.isEmpty {
        EmptyStatePlaceholder(
          title: "履歴はありません",
          systemImage: "clock",
          description: model.settings.keepHistory
            ? "音声入力するとここに表示されます。" : "設定で履歴保存を有効にすると、テキストのみ記録します。"
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
        .searchable(text: $searchText, prompt: "テキストまたはアプリ名を検索")
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
        .help("直前に使っていたアプリのカーソル位置へ入力")
        Button(action: onCopy) {
          Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .help("コピー")
        Button(role: .destructive, action: onDelete) {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("削除")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
  }
}
