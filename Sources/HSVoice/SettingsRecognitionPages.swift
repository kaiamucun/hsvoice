import AppKit
import SwiftUI

// MARK: - Recognition (language, engine, microphone)

struct RecognitionSettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @StateObject private var probe = MicrophoneLevelProbe()
  @State private var devices: [AudioInputDevice] = []

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  var body: some View {
    SettingsPageScaffold(.recognition) {
      Section(L.t("表示言語", "Display Language", "显示语言", "표시 언어")) {
        Picker(selection: $settings.appLanguage) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.displayName).tag(language)
          }
        } label: {
          SettingLabel(
            title: L.t("アプリの表示言語", "App display language", "应用显示语言", "앱 표시 언어"),
            detail: L.t(
              "メニューや設定画面など、アプリ自体の表示言語です。",
              "The language of the app's own menus and settings.",
              "应用菜单和设置界面的显示语言。", "앱 메뉴와 설정 화면의 표시 언어입니다."))
        }
      }

      Section(L.t("認識言語", "Recognition Language", "识别语言", "인식 언어")) {
        Picker(selection: $settings.localeIdentifier) {
          ForEach(VoiceLocale.recommended) { locale in
            Text(locale.nativeName).tag(locale.identifier)
          }
        } label: {
          SettingLabel(
            title: L.t("話す言語", "Spoken language", "所说语言", "말하는 언어"),
            detail: L.t(
              "メニューバーからもすぐに切り替えられます。", "Can also be switched from the menu bar.",
              "也可从菜单栏快速切换。", "메뉴 막대에서도 바로 전환할 수 있습니다."))
        }
        if model.analyzerEngineSupported {
          Toggle(isOn: $settings.useAnalyzerEngine) {
            SettingLabel(
              title: L.t(
                "高精度認識エンジンを使用（macOS 26以降）", "Use the high-accuracy engine (macOS 26+)",
                "使用高精度识别引擎（macOS 26及以上）", "고정밀 인식 엔진 사용（macOS 26 이상）"),
              detail: analyzerEngineCaption)
          }
        }
        Toggle(isOn: $settings.preferOnDevice) {
          SettingLabel(
            title: L.t(
              "対応している場合はオンデバイス認識を使用", "Prefer on-device recognition when available",
              "支持时优先使用设备端识别", "지원되는 경우 온디바이스 인식 사용"),
            detail: L.t(
              "従来エンジンで、言語が対応していればこのMacの中だけで認識します。",
              "With the classic engine, recognizes on this Mac only when the language allows it.",
              "在传统引擎中，若语言支持则仅在这台Mac上识别。",
              "기존 엔진에서 언어가 지원되면 이 Mac 안에서만 인식합니다."))
        }
        Toggle(isOn: $settings.spokenFormattingCommands) {
          SettingLabel(
            title: L.t(
              "「改行」「新しい段落」などの音声コマンドを整形", "Apply spoken commands like \"new line\" and \"new paragraph\"",
              "识别“换行”“新段落”等语音命令", "\"줄바꿈\" \"새 단락\" 등 음성 명령 적용"),
            detail: L.t(
              "話した「改行」「新しい段落」「new line」を実際の改行に変換します。",
              "Turns a spoken “new line” or “new paragraph” into an actual line break.",
              "将说出的“换行”“新段落”“new line”转换为实际换行。",
              "말한 「줄바꿈」「새 단락」「new line」을 실제 줄바꿈으로 바꿉니다."))
        }
        SettingCaption(
          L.t(
            "選択した言語やmacOSの状態によっては、Appleの音声認識サービスへ接続します。高精度エンジンは常にこのMacの中だけで動作します。",
            "Depending on the selected language and macOS state, Apple's speech service may be used over the network. The high-accuracy engine always runs entirely on this Mac.",
            "根据所选语言和macOS状态，可能会连接Apple语音识别服务。高精度引擎始终只在这台Mac上运行。",
            "선택한 언어와 macOS 상태에 따라 Apple 음성 인식 서비스에 연결될 수 있습니다. 고정밀 엔진은 항상 이 Mac 안에서만 동작합니다."))
      }

      Section(L.t("マイク", "Microphone", "麦克风", "마이크")) {
        Picker(selection: microphoneSelection) {
          Text(L.t("システムのデフォルト", "System default", "系统默认", "시스템 기본값")).tag("")
          ForEach(devices) { device in
            Text(device.name).tag(device.uid)
          }
          if let uid = settings.preferredInputDeviceUID, !devices.contains(where: { $0.uid == uid }) {
            Text(L.t("（接続されていないマイク）", "(disconnected microphone)", "（未连接的麦克风）", "（연결되지 않은 마이크）"))
              .tag(uid)
          }
        } label: {
          SettingLabel(
            title: L.t("使用するマイク", "Input device", "使用的麦克风", "사용할 마이크"),
            detail: L.t(
              "選んだマイクが見つからないときはシステムのデフォルトを使います。",
              "Falls back to the system default when the chosen microphone is missing.",
              "找不到所选麦克风时使用系统默认设备。", "선택한 마이크를 찾지 못하면 시스템 기본값을 사용합니다."))
        }
        HStack(spacing: 12) {
          Button {
            if probe.isRunning {
              probe.stop()
            } else {
              probe.start(preferredUID: settings.preferredInputDeviceUID)
            }
          } label: {
            Label(
              probe.isRunning
                ? L.t("停止", "Stop", "停止", "정지") : L.t("テスト", "Test", "测试", "테스트"),
              systemImage: probe.isRunning ? "stop.fill" : "speaker.wave.2")
          }
          ProgressView(value: probe.level)
            .progressViewStyle(.linear)
            .tint(probe.level > 0.02 ? .green : .secondary)
          Button {
            devices = AudioInputDevices.available()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help(L.t("マイク一覧を更新", "Refresh the list", "刷新列表", "목록 새로고침"))
        }
        if let error = probe.errorMessage {
          Text(error).font(.caption).foregroundStyle(.red)
        }
        SettingCaption(
          L.t(
            "「テスト」を押して話すと、数秒間レベルが表示されます。バーが動かない場合は別のマイクを選ぶか、権限を確認してください。",
            "Press Test and speak — the level shows for a few seconds. If the bar stays flat, pick another microphone or check the permission.",
            "点按“测试”并说话，几秒内会显示音量。若音量条不动，请选择其他麦克风或检查权限。",
            "「테스트」를 누르고 말하면 몇 초 동안 레벨이 표시됩니다. 막대가 움직이지 않으면 다른 마이크를 선택하거나 권한을 확인하세요."))
      }
    }
    .onAppear { devices = AudioInputDevices.available() }
    .onDisappear { probe.stop() }
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var microphoneSelection: Binding<String> {
    Binding(
      get: { settings.preferredInputDeviceUID ?? "" },
      set: { settings.preferredInputDeviceUID = $0.isEmpty ? nil : $0 }
    )
  }

  private var analyzerEngineCaption: String {
    if !settings.useAnalyzerEngine {
      return L.t(
        "オフの間は従来エンジンを使用します。",
        "While off, the classic engine is used.",
        "关闭时使用传统引擎。",
        "꺼져 있는 동안은 기존 엔진을 사용합니다.")
    }
    if model.analyzerEngineReady {
      return L.t(
        "この言語の高精度モデルは準備済みです。常にこのMacの中だけで認識します。",
        "The high-accuracy model for this language is ready. It always recognizes on this Mac only.",
        "该语言的高精度模型已就绪，始终仅在这台Mac上识别。",
        "이 언어의 고정밀 모델이 준비되었습니다. 항상 이 Mac 안에서만 인식합니다.")
    }
    return L.t(
      "高精度モデルを準備中です（初回は自動ダウンロードあり）。準備が整うまでは従来エンジンを使用します。",
      "The high-accuracy model is being prepared (first use downloads it). The classic engine is used until it's ready.",
      "高精度模型正在准备中（首次会自动下载）。就绪前使用传统引擎。",
      "고정밀 모델을 준비 중입니다（최초 1회 자동 다운로드）. 준비될 때까지 기존 엔진을 사용합니다.")
  }
}

// MARK: - Dictionary

struct DictionarySettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @FocusState private var focusedEntry: UUID?

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  var body: some View {
    SettingsPageScaffold(.dictionary) {
      HStack(spacing: 12) {
        Text("\(settings.dictionaryEntries.count)/\(TextReplacer.dictionaryLimit)")
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
        Button {
          if let entry = settings.addDictionaryEntry() {
            focusedEntry = entry.id
          }
        } label: {
          Label(L.t("追加", "Add", "添加", "추가"), systemImage: "plus")
        }
        .disabled(settings.dictionaryEntries.count >= TextReplacer.dictionaryLimit)
      }
    } content: {
      if settings.dictionaryEntries.isEmpty {
        Section {
          VStack(spacing: 6) {
            Text(L.t("カスタム単語がまだ追加されていません", "No custom words yet", "尚未添加自定义单词", "아직 사용자 단어가 없습니다"))
              .foregroundStyle(.secondary)
            Text(
              L.t(
                "「追加」を押して、よく誤認識される人名・製品名・専門用語を登録してください。",
                "Press Add to register names, products, and terms that are often misheard.",
                "点按“添加”，登记常被误识别的人名、产品名和术语。",
                "「추가」를 눌러 자주 잘못 인식되는 인명·제품명·전문 용어를 등록하세요."))
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 28)
        }
      } else {
        Section {
          ForEach($settings.dictionaryEntries) { $entry in
            HStack(spacing: 10) {
              TextField(
                "", text: $entry.term,
                prompt: Text(L.t("正しい表記", "Correct spelling", "正确写法", "올바른 표기"))
              )
              .textFieldStyle(.roundedBorder)
              .focused($focusedEntry, equals: entry.id)
              Image(systemName: "arrow.left")
                .foregroundStyle(.tertiary)
              TextField(
                "", text: $entry.spokenForms,
                prompt: Text(
                  L.t(
                    "読み・誤認識例（カンマ区切り、任意）", "Misheard forms (comma-separated, optional)",
                    "读音/误识别例（逗号分隔，可选）", "읽기·오인식 예（쉼표 구분, 선택）"))
              )
              .textFieldStyle(.roundedBorder)
              Button(role: .destructive) {
                settings.removeDictionaryEntry(id: entry.id)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
              .foregroundStyle(.secondary)
              .help(L.t("削除", "Delete", "删除", "삭제"))
            }
            .labelsHidden()
          }
        } header: {
          HStack(spacing: 10) {
            Text(L.t("正しい表記", "Correct spelling", "正确写法", "올바른 표기"))
              .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 16)
            Text(L.t("読み・誤認識例", "Misheard forms", "读音/误识别例", "읽기·오인식 예"))
              .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 24)
          }
        }
      }

      Section(L.t("仕組み", "How it works", "工作方式", "작동 방식")) {
        Label {
          SettingLabel(
            title: L.t("誤認識を正しい表記に置き換える", "Misheard forms become the correct spelling", "将误识别替换为正确写法", "오인식을 올바른 표기로 치환"),
            detail: L.t(
              "「読み・誤認識例」に書いた語が認識結果に現れると「正しい表記」に置き換えます。高精度エンジンでも従来エンジンでも有効です。例: JOPTGames ← ジョプトゲームズ, ジョプトゲーム",
              "When a misheard form shows up in the transcript it is replaced by the correct spelling. Works with both engines. e.g. JOPTGames ← ジョプトゲームズ",
              "识别结果中出现“误识别例”时替换为“正确写法”。两种引擎均有效。例：JOPTGames ← ジョプトゲームズ",
              "「읽기·오인식 예」에 적은 말이 인식 결과에 나타나면 「올바른 표기」로 바꿉니다. 두 엔진 모두에서 동작합니다. 예: JOPTGames ← ジョプトゲームズ"))
        } icon: {
          Image(systemName: "arrow.left.arrow.right").foregroundStyle(.tint)
        }
        Label {
          SettingLabel(
            title: L.t("表記だけでも効果があります", "The spelling alone still helps", "仅写法也有效", "표기만 적어도 효과가 있습니다"),
            detail: L.t(
              "「正しい表記」は従来エンジンの認識ヒント（先頭100語）と、AI整形の表記指定に使われます。",
              "The correct spelling is passed to the classic engine as a hint (first 100) and to AI polish as the required spelling.",
              "“正确写法”会作为传统引擎的识别提示（前100条）和AI润色的写法指定。",
              "「올바른 표기」는 기존 엔진의 인식 힌트（앞 100개）와 AI 다듬기의 표기 지정에 사용됩니다."))
        } icon: {
          Image(systemName: "lightbulb").foregroundStyle(.tint)
        }
      }
    }
    .disabled(!model.state.allowsConfigurationChanges)
  }
}

// MARK: - Replacements

struct ReplacementSettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @FocusState private var focusedRule: UUID?

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  private struct Example: Identifiable {
    let id = UUID()
    let trigger: String
    let replacement: String
  }

  private var examples: [Example] {
    [
      Example(
        trigger: L.t("仕事メール", "work email", "工作邮箱", "업무 메일"),
        replacement: "yourname@company.jp"),
      Example(
        trigger: L.t("会議リンク", "meeting link", "会议链接", "회의 링크"),
        replacement: "https://meet.google.com/xxx-xxxx-xxx"),
      Example(
        trigger: L.t("定型あいさつ", "greeting", "问候语", "인사말"),
        replacement: L.t(
          "いつもお世話になっております。株式会社〇〇の〇〇です。",
          "Thank you as always. This is ___ from ___.",
          "一直承蒙关照。我是〇〇公司的〇〇。",
          "항상 신세 지고 있습니다. 〇〇의 〇〇입니다.")),
    ]
  }

  var body: some View {
    SettingsPageScaffold(.replacements) {
      HStack(spacing: 12) {
        Text("\(settings.replacementRules.count)/\(TextReplacer.replacementLimit)")
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
        Button {
          if let rule = settings.addReplacementRule() {
            focusedRule = rule.id
          }
        } label: {
          Label(L.t("追加", "Add", "添加", "추가"), systemImage: "plus")
        }
        .disabled(settings.replacementRules.count >= TextReplacer.replacementLimit)
      }
    } content: {
      if settings.replacementRules.isEmpty {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            Text(L.t("繰り返し入力する文を、ひと言で。", "Say a word, get the whole text.", "一个词，输入整段文字。", "한마디로 긴 문장을."))
              .font(.title3.weight(.semibold))
            Text(
              L.t(
                "トリガーの言葉を話すと、HS Voiceが登録したテキストに置き換えます。メールアドレス、会議のURL、定型のあいさつに。",
                "Say the trigger and HS Voice swaps in the registered text — email addresses, meeting links, standard greetings.",
                "说出触发词，HS Voice会替换为登记的文本。适合邮箱、会议链接、固定问候语。",
                "트리거 말을 하면 HS Voice가 등록한 텍스트로 바꿉니다. 이메일 주소, 회의 URL, 정형 인사말에."))
              .font(.callout)
              .foregroundStyle(.secondary)
            ForEach(examples) { example in
              HStack(spacing: 10) {
                chip(example.trigger)
                Image(systemName: "arrow.right").foregroundStyle(.tint)
                chip(example.replacement)
                Spacer()
                Button(L.t("この例を追加", "Add this", "添加此例", "이 예 추가")) {
                  if let rule = settings.addReplacementRule(
                    trigger: example.trigger, replacement: example.replacement)
                  {
                    focusedRule = rule.id
                  }
                }
                .controlSize(.small)
              }
            }
          }
          .padding(.vertical, 8)
        }
      } else {
        Section {
          ForEach($settings.replacementRules) { $rule in
            HStack(spacing: 10) {
              TextField(
                "", text: $rule.trigger,
                prompt: Text(L.t("言う言葉", "Say this", "说出的词", "말할 단어"))
              )
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 200)
              .focused($focusedRule, equals: rule.id)
              Image(systemName: "arrow.right").foregroundStyle(.tint)
              TextField(
                "", text: $rule.replacement,
                prompt: Text(L.t("置き換えるテキスト", "Replace with", "替换为的文本", "바꿀 텍스트"))
              )
              .textFieldStyle(.roundedBorder)
              Button(role: .destructive) {
                settings.removeReplacementRule(id: rule.id)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
              .foregroundStyle(.secondary)
              .help(L.t("削除", "Delete", "删除", "삭제"))
            }
            .labelsHidden()
          }
        } header: {
          HStack(spacing: 10) {
            Text(L.t("言う言葉", "Say this", "说出的词", "말할 단어"))
              .frame(width: 200, alignment: .leading)
            Color.clear.frame(width: 16)
            Text(L.t("置き換えるテキスト", "Replace with", "替换为的文本", "바꿀 텍스트"))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        } footer: {
          SettingCaption(
            L.t(
              "認識結果の中に「言う言葉」がそのまま現れたときに置き換えます。英単語は単語単位で、大文字小文字は区別しません。辞書の置き換えが先に適用されます。",
              "Applied when the trigger appears verbatim in the transcript. Latin words match whole words, case-insensitively. Dictionary corrections run first.",
              "识别结果中原样出现“说出的词”时替换。英文按整词匹配，不区分大小写。词典替换先执行。",
              "인식 결과에 「말할 단어」가 그대로 나타나면 바꿉니다. 영단어는 단어 단위로, 대소문자는 구분하지 않습니다. 사전 치환이 먼저 적용됩니다."))
        }
      }
    }
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private func chip(_ text: String) -> some View {
    Text(text)
      .font(.callout)
      .lineLimit(1)
      .truncationMode(.middle)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
      .frame(maxWidth: 300, alignment: .leading)
  }
}
