import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @ObservedObject private var permissions: PermissionsManager

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
    _permissions = ObservedObject(wrappedValue: model.permissions)
  }

  var body: some View {
    TabView {
      generalTab
        .tabItem { Label("一般", systemImage: "switch.2") }

      languageTab
        .tabItem { Label("言語と辞書", systemImage: "character.book.closed") }

      privacyTab
        .tabItem { Label("プライバシー", systemImage: "hand.raised") }

      permissionsTab
        .tabItem { Label("権限", systemImage: "checkmark.shield") }
    }
    .padding(20)
    .frame(width: 670, height: 540)
    .onAppear { model.refreshPermissions() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      model.refreshPermissions()
    }
  }

  private var generalTab: some View {
    Form {
      Section("音声入力") {
        Picker("起動方法", selection: $settings.activationMode) {
          ForEach(ActivationMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        Picker(
          "入力方法",
          selection: Binding(
            get: { settings.insertionMode },
            set: { model.setInsertionMode($0) }
          )
        ) {
          ForEach(InsertionMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        Text(settings.insertionMode.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
        Picker(
          "グローバルショートカット",
          selection: Binding(
            get: { settings.shortcutChoice },
            set: { model.setShortcut($0) }
          )
        ) {
          ForEach(ShortcutChoice.allCases) { shortcut in
            Text(shortcut.displayName).tag(shortcut)
          }
        }
        if !model.shortcutAvailable {
          Label(shortcutWarning, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
        Text("1回の音声入力は55秒で安全に終了します。長文は段落ごとに分けると安定します。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Mac") {
        Toggle(
          "ログイン時にHS Voiceを起動",
          isOn: Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
          )
        )
        if let error = settings.launchAtLoginError {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      Section("サポート") {
        HStack {
          Button("セットアップをもう一度表示") {
            model.showOnboarding()
          }
          Button("診断情報をコピー") {
            model.copyDiagnostics()
          }
          Spacer()
          Text(model.versionDisplay)
            .foregroundStyle(.secondary)
        }
        Text("診断情報に音声、入力本文、辞書内容、ユーザー名、端末名は含まれません。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var shortcutWarning: String {
    if settings.shortcutChoice == .functionKey {
      return "fnキーを使うには、アクセシビリティでHS Voiceを許可してください。fnキーがないキーボードでは別の組み合わせを選べます。"
    }
    return "\(settings.shortcutChoice.displayName)は別のアプリで使用されています。別の組み合わせを選んでください。"
  }

  private var languageTab: some View {
    Form {
      Section("認識言語") {
        Picker("話す言語", selection: $settings.localeIdentifier) {
          ForEach(VoiceLocale.recommended) { locale in
            Text(locale.nativeName).tag(locale.identifier)
          }
        }
        Toggle("対応している場合はオンデバイス認識を使用", isOn: $settings.preferOnDevice)
        Toggle("「改行」「新しい段落」などの音声コマンドを整形", isOn: $settings.spokenFormattingCommands)
        Text("選択した言語やmacOSの状態によっては、Appleの音声認識サービスへ接続します。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("カスタム辞書") {
        TextEditor(text: $settings.customVocabulary)
          .font(.body)
          .frame(minHeight: 150)
          .overlay(alignment: .topLeading) {
            if settings.customVocabulary.isEmpty {
              Text("人名、製品名、専門用語を1行に1つ入力")
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
        Text("最大100語を次回の音声入力から認識ヒントとして使用します。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var privacyTab: some View {
    Form {
      Section("保存") {
        Toggle("音声入力の履歴をこのMacに保存", isOn: $settings.keepHistory)
        Text("初期設定では保存しません。有効にした場合も音声ファイルは保存せず、テキストのみ最大100件をローカルに保管します。")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Button("履歴を表示") { model.showHistory() }
          Button("履歴をすべて削除", role: .destructive) { model.history.clear() }
            .disabled(model.history.entries.isEmpty)
        }
      }

      Section("データの扱い") {
        Label("HS Voice独自のサーバーへ音声やテキストを送信しません", systemImage: "server.rack")
        Label("カスタム辞書と設定はこのMac内に保存します", systemImage: "internaldrive")
        Label("Appleの音声認識がネットワークを使用する場合があります", systemImage: "network")
      }
    }
    .formStyle(.grouped)
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var permissionsTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("macOSの権限")
        .font(.title3.bold())
      Text("システム設定からこの画面へ戻ると、許可状態を自動で更新します。")
        .font(.caption)
        .foregroundStyle(.secondary)

      PermissionRow(
        symbol: "mic.fill",
        title: "マイク",
        detail: "音声を取り込む",
        granted: permissions.microphoneGranted,
        action: permissions.openMicrophoneSettings
      )
      PermissionRow(
        symbol: "waveform.badge.magnifyingglass",
        title: "音声認識",
        detail: "音声をテキストに変換する",
        granted: permissions.speechGranted,
        action: permissions.openSpeechSettings
      )
      PermissionRow(
        symbol: "text.cursor",
        title: "アクセシビリティ",
        detail: "他のアプリへテキストを入力する",
        granted: permissions.accessibilityGranted,
        action: permissions.openAccessibilitySettings
      )

      HStack {
        Button("マイクと音声認識をリクエスト") {
          Task { await model.requestPermissions() }
        }
        .buttonStyle(.borderedProminent)
        Spacer()
        Button("状態を更新") { model.refreshPermissions() }
      }
      .padding(.top, 6)
    }
    .padding(12)
    .disabled(!model.state.allowsConfigurationChanges)
  }
}
