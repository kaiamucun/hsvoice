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
        .tabItem { Label(L.t("一般", "General", "通用", "일반"), systemImage: "switch.2") }

      languageTab
        .tabItem {
          Label(L.t("言語と辞書", "Language & Dictionary", "语言与词典", "언어와 사전"), systemImage: "character.book.closed")
        }

      privacyTab
        .tabItem { Label(L.t("プライバシー", "Privacy", "隐私", "프라이버시"), systemImage: "hand.raised") }

      permissionsTab
        .tabItem { Label(L.t("権限", "Permissions", "权限", "권한"), systemImage: "checkmark.shield") }
    }
    .padding(20)
    .frame(width: 670, height: 540)
    .onAppear { model.refreshPermissions() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      model.refreshPermissions()
    }
    // System Settings usually stays frontmost while the user flips a toggle, so
    // waiting for HS Voice to become active again left the status looking
    // stale. A cheap poll keeps 許可済み current the moment macOS grants it.
    // `.task` survives body re-evaluation and is cancelled when the window closes.
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        model.refreshPermissionStatus()
      }
    }
  }

  private var generalTab: some View {
    Form {
      Section(L.t("音声入力", "Dictation", "语音输入", "음성 입력")) {
        Picker(L.t("起動方法", "Activation", "启动方式", "시작 방식"), selection: $settings.activationMode) {
          ForEach(ActivationMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        Picker(
          L.t("入力方法", "Insertion", "输入方式", "입력 방식"),
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
        HStack(alignment: .firstTextBaseline) {
          Text(L.t("グローバルショートカット", "Global shortcut", "全局快捷键", "전역 단축키"))
          Spacer()
          ShortcutRecorderField(
            keyLabels: settings.shortcutChoice.keyLabels,
            captureDisabled: model.isCapturingShortcut,
            isConflicting: { combo in
              settings.repeatShortcutEnabled && settings.repeatShortcut == combo
            },
            onBegin: { model.beginShortcutCapture() },
            onEnd: { model.endShortcutCapture() },
            onCapture: { model.setShortcut(.custom($0)) }
          )
          Menu {
            ForEach(ShortcutChoice.presets) { preset in
              Button {
                model.setShortcut(preset)
              } label: {
                if settings.shortcutChoice == preset {
                  Label(preset.displayName, systemImage: "checkmark")
                } else {
                  Text(preset.displayName)
                }
              }
            }
          } label: {
            Image(systemName: "chevron.up.chevron.down")
          }
          .fixedSize()
          .disabled(model.isCapturingShortcut)
          .help(L.t("プリセットから選ぶ", "Choose a preset", "从预设中选择", "프리셋에서 선택"))
        }
        Text(
          L.t(
            "「変更…」を押して、使いたいキーの組み合わせやマウスボタンをそのまま押すと登録できます（例: ⌘⇧V、マウスのサイドボタン。M3=中央、M4/M5=サイド）。",
            "Press “Change…”, then type the key combination or click the mouse button you want (e.g. ⌘⇧V, or a side button; M3 = middle, M4/M5 = side).",
            "点按“更改…”后直接按下想使用的组合键或鼠标按钮即可登记（例如 ⌘⇧V、鼠标侧键。M3=中键、M4/M5=侧键）。",
            "「변경…」을 누른 뒤 사용할 키 조합이나 마우스 버튼을 그대로 누르면 등록됩니다（예: ⌘⇧V, 마우스 사이드 버튼. M3=가운데, M4/M5=사이드）."))
          .font(.caption)
          .foregroundStyle(.secondary)
        if !model.shortcutAvailable {
          Label(shortcutWarning, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
        Toggle(
          L.t(
            "前回の音声入力を再入力するショートカットを使う",
            "Use a shortcut to re-insert the last dictation",
            "使用快捷键重新输入上次的语音内容",
            "마지막 음성 입력을 다시 입력하는 단축키 사용"),
          isOn: Binding(
            get: { settings.repeatShortcutEnabled },
            set: { model.setRepeatShortcutEnabled($0) }
          ))
          .disabled(model.isCapturingShortcut)
        if settings.repeatShortcutEnabled {
          HStack(alignment: .firstTextBaseline) {
            Text(L.t("再入力ショートカット", "Re-insert shortcut", "重新输入快捷键", "재입력 단축키"))
            Spacer()
            ShortcutRecorderField(
              keyLabels: settings.repeatShortcut.keyLabels,
              captureDisabled: model.isCapturingShortcut,
              isConflicting: { combo in settings.shortcutChoice.inputCombo == combo },
              onBegin: { model.beginShortcutCapture() },
              onEnd: { model.endShortcutCapture() },
              onCapture: { model.setRepeatShortcut($0) }
            )
          }
          if !model.repeatShortcutAvailable {
            Label(repeatShortcutWarning, systemImage: "exclamationmark.triangle")
              .font(.caption)
              .foregroundStyle(.orange)
          }
          Text(
            L.t(
              "最後の音声入力テキストをカーソル位置にもう一度入力します（メニューバーの「直前の入力」の再入力と同じ動作）。",
              "Types your last dictation at the cursor again (same as re-inserting from “Last dictation” in the menu bar).",
              "将上次语音输入的文本再次输入到光标位置（与菜单栏“上次输入”的重新输入相同）。",
              "마지막 음성 입력 텍스트를 커서 위치에 다시 입력합니다（메뉴 막대「마지막 입력」의 재입력과 동일）."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Toggle(
          L.t("開始・終了のサウンドを再生", "Play start / stop sounds", "播放开始/结束提示音", "시작·종료 사운드 재생"),
          isOn: $settings.soundFeedback)
        Toggle(
          L.t(
            "待機中も画面下に小さなアイコンを表示", "Show the small idle icon at the bottom of the screen",
            "待机时在屏幕底部显示小图标", "대기 중에도 화면 하단에 작은 아이콘 표시"),
          isOn: $settings.showIdleIndicator)
        Text(
          L.t(
            "録音中はescキーでキャンセルできます。1回の音声入力は55秒で安全に終了します。長文は段落ごとに分けると安定します。",
            "Press esc while recording to cancel. Each dictation safely stops after 55 seconds; for long texts, dictate paragraph by paragraph.",
            "录音时按esc键可取消。每次语音输入将在55秒后安全结束。长文本建议分段输入。",
            "녹음 중 esc 키로 취소할 수 있습니다. 한 번의 음성 입력은 55초 후 안전하게 종료됩니다. 긴 글은 문단별로 나누면 안정적입니다."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section(L.t("AI整形・要約", "AI Polish & Summarize", "AI润色与摘要", "AI 다듬기·요약")) {
        if model.refinementSupported {
          Toggle(
            L.t(
              "入力前にAIで文章を仕上げる（Apple Intelligence）", "Polish text with AI before inserting (Apple Intelligence)",
              "输入前用AI润色文本（Apple Intelligence）", "입력 전에 AI로 문장 다듬기（Apple Intelligence）"),
            isOn: $settings.aiRefinementEnabled)
          if settings.aiRefinementEnabled {
            Picker(L.t("処理モード", "Mode", "处理模式", "처리 모드"), selection: $settings.aiRefinementMode) {
              ForEach(RefinementMode.allCases) { mode in
                Text(mode.label).tag(mode)
              }
            }
            Text(settings.aiRefinementMode.detail)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(refinementCaption)
            .font(.caption)
            .foregroundStyle(refinementCaptionIsWarning ? .orange : .secondary)
        } else {
          Text(
            L.t(
              "AIによる整形・要約は、macOS 26以降のApple Intelligence対応Macで利用できます。",
              "AI polish & summarize requires macOS 26 or later on an Apple Intelligence capable Mac.",
              "AI润色与摘要需要macOS 26或更高版本，且Mac支持Apple Intelligence。",
              "AI 다듬기·요약은 macOS 26 이상의 Apple Intelligence 지원 Mac에서 사용할 수 있습니다."))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section("Mac") {
        Toggle(
          L.t("ログイン時にHS Voiceを起動", "Launch HS Voice at login", "登录时启动HS Voice", "로그인 시 HS Voice 시작"),
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

      Section(L.t("サポート", "Support", "支持", "지원")) {
        HStack {
          Button(L.t("セットアップをもう一度表示", "Show setup again", "重新显示设置向导", "설정 안내 다시 보기")) {
            model.showOnboarding()
          }
          Button(L.t("診断情報をコピー", "Copy diagnostics", "复制诊断信息", "진단 정보 복사")) {
            model.copyDiagnostics()
          }
          Spacer()
          Text(model.versionDisplay)
            .foregroundStyle(.secondary)
        }
        Text(
          L.t(
            "診断情報に音声、入力本文、辞書内容、ユーザー名、端末名は含まれません。",
            "Diagnostics never include audio, dictated text, dictionary contents, your user name, or the device name.",
            "诊断信息不包含音频、输入内容、词典内容、用户名或设备名。",
            "진단 정보에는 오디오, 입력한 본문, 사전 내용, 사용자 이름, 기기 이름이 포함되지 않습니다."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var refinementCaption: String {
    switch RefinementService.availability() {
    case .available:
      return L.t(
        "処理はこのMacの中だけで行われます。AI処理の分だけ、入力までに数秒かかることがあります。うまく仕上がらなかった場合は認識したままの文章を入力します。",
        "Processing happens entirely on this Mac. AI adds a few seconds before insertion; if it can't improve the text, the raw transcript is inserted.",
        "处理完全在这台Mac上进行。AI处理会使输入多花几秒；若处理不理想，将输入原始识别文本。",
        "처리는 이 Mac 안에서만 이루어집니다. AI 처리만큼 입력까지 몇 초 걸릴 수 있으며, 잘 다듬지 못한 경우 인식된 원문을 입력합니다.")
    case .appleIntelligenceOff:
      return L.t(
        "システム設定でApple Intelligenceをオンにすると使用できます。オンになるまでは認識したままの文章を入力します。",
        "Turn on Apple Intelligence in System Settings to use this. Until then, the raw transcript is inserted.",
        "在系统设置中开启Apple Intelligence后即可使用。开启前将输入原始识别文本。",
        "시스템 설정에서 Apple Intelligence를 켜면 사용할 수 있습니다. 켜기 전까지는 인식된 원문을 입력합니다.")
    case .modelNotReady:
      return L.t(
        "Apple Intelligenceのモデルを準備中です。準備が整うまでは認識したままの文章を入力します。",
        "The Apple Intelligence model is still getting ready. Until then, the raw transcript is inserted.",
        "Apple Intelligence模型正在准备中。就绪前将输入原始识别文本。",
        "Apple Intelligence 모델을 준비 중입니다. 준비될 때까지 인식된 원문을 입력합니다.")
    case .deviceNotSupported:
      return L.t(
        "このMacはApple Intelligenceに対応していないため、認識したままの文章を入力します。",
        "This Mac doesn't support Apple Intelligence, so the raw transcript is inserted.",
        "这台Mac不支持Apple Intelligence，将输入原始识别文本。",
        "이 Mac은 Apple Intelligence를 지원하지 않으므로 인식된 원문을 입력합니다.")
    case .osTooOld, .unavailable:
      return L.t(
        "現在この機能を利用できないため、認識したままの文章を入力します。",
        "This feature isn't available right now, so the raw transcript is inserted.",
        "该功能当前不可用，将输入原始识别文本。",
        "현재 이 기능을 사용할 수 없어 인식된 원문을 입력합니다.")
    }
  }

  private var refinementCaptionIsWarning: Bool {
    settings.aiRefinementEnabled && RefinementService.availability() != .available
  }

  private var analyzerEngineCaption: String {
    if !settings.useAnalyzerEngine {
      return L.t(
        "オフの間は従来エンジンを使用し、カスタム辞書のヒントが有効になります。",
        "While off, the classic engine is used and custom-dictionary hints apply.",
        "关闭时使用传统引擎，自定义词典提示生效。",
        "꺼져 있는 동안은 기존 엔진을 사용하며 사용자 사전 힌트가 적용됩니다.")
    }
    if model.analyzerEngineReady {
      return L.t(
        "この言語の高精度モデルは準備済みです。カスタム辞書のヒントは高精度エンジンでは適用されません。辞書を優先する場合はオフにしてください。",
        "The high-accuracy model for this language is ready. Custom-dictionary hints don't apply to it — turn this off if the dictionary matters more.",
        "该语言的高精度模型已就绪。自定义词典提示不适用于高精度引擎；若词典更重要请关闭此项。",
        "이 언어의 고정밀 모델이 준비되었습니다. 사용자 사전 힌트는 고정밀 엔진에 적용되지 않으니, 사전이 더 중요하면 꺼 주세요.")
    }
    return L.t(
      "高精度モデルを準備中です（初回は自動ダウンロードあり）。準備が整うまでは従来エンジンを使用します。",
      "The high-accuracy model is being prepared (first use downloads it). The classic engine is used until it's ready.",
      "高精度模型正在准备中（首次会自动下载）。就绪前使用传统引擎。",
      "고정밀 모델을 준비 중입니다（최초 1회 자동 다운로드）. 준비될 때까지 기존 엔진을 사용합니다.")
  }

  private var vocabularyCaption: String {
    let count = settings.vocabularyTerms.count
    return L.t(
      "現在\(count)/100語。次回の音声入力から認識ヒントとして使用します（従来エンジンのみ）。",
      "\(count)/100 terms. Used as recognition hints from the next dictation (classic engine only).",
      "当前\(count)/100条。从下次语音输入起作为识别提示（仅传统引擎）。",
      "현재 \(count)/100개. 다음 음성 입력부터 인식 힌트로 사용됩니다（기존 엔진만）.")
  }

  private var repeatShortcutWarning: String {
    if settings.repeatShortcut == settings.shortcutChoice.inputCombo {
      return L.t(
        "\(settings.repeatShortcut.displayName)は音声入力の開始に割り当てられています。別の組み合わせを選んでください。",
        "\(settings.repeatShortcut.displayName) is already assigned to starting dictation. Please pick another combination.",
        "\(settings.repeatShortcut.displayName)已分配给开始语音输入，请选择其他组合。",
        "\(settings.repeatShortcut.displayName)은(는) 음성 입력 시작에 할당되어 있습니다. 다른 조합을 선택해 주세요.")
    }
    return L.t(
      "\(settings.repeatShortcut.displayName)は別のアプリで使用されています。別の組み合わせを選んでください。",
      "\(settings.repeatShortcut.displayName) is taken by another app. Please pick another combination.",
      "\(settings.repeatShortcut.displayName)已被其他应用占用，请选择其他组合。",
      "\(settings.repeatShortcut.displayName)은(는) 다른 앱에서 사용 중입니다. 다른 조합을 선택해 주세요.")
  }

  private var shortcutWarning: String {
    if settings.shortcutChoice == .functionKey {
      return L.t(
        "fnキーを使うには、アクセシビリティでHS Voiceを許可してください。fnキーがないキーボードでは別の組み合わせを選べます。",
        "To use the fn key, allow HS Voice under Accessibility. On keyboards without fn, pick another combination.",
        "要使用fn键，请在辅助功能中允许HS Voice。没有fn键的键盘可选择其他组合。",
        "fn 키를 사용하려면 손쉬운 사용에서 HS Voice를 허용해 주세요. fn 키가 없는 키보드에서는 다른 조합을 선택할 수 있습니다.")
    }
    return L.t(
      "\(settings.shortcutChoice.displayName)は別のアプリで使用されています。別の組み合わせを選んでください。",
      "\(settings.shortcutChoice.displayName) is taken by another app. Please pick another combination.",
      "\(settings.shortcutChoice.displayName)已被其他应用占用，请选择其他组合。",
      "\(settings.shortcutChoice.displayName)은(는) 다른 앱에서 사용 중입니다. 다른 조합을 선택해 주세요.")
  }

  private var languageTab: some View {
    Form {
      Section(L.t("表示言語", "Display Language", "显示语言", "표시 언어")) {
        Picker(
          L.t("アプリの表示言語", "App display language", "应用显示语言", "앱 표시 언어"),
          selection: $settings.appLanguage
        ) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.displayName).tag(language)
          }
        }
        Text(
          L.t(
            "メニューや設定画面など、アプリ自体の表示言語です。話す言語は下の「認識言語」で選びます。",
            "The language of the app's own menus and settings. The language you speak is chosen under Recognition Language below.",
            "应用菜单和设置界面的显示语言。所说的语言请在下方“识别语言”中选择。",
            "앱 메뉴와 설정 화면의 표시 언어입니다. 말하는 언어는 아래 '인식 언어'에서 선택하세요."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section(L.t("認識言語", "Recognition Language", "识别语言", "인식 언어")) {
        Picker(L.t("話す言語", "Spoken language", "所说语言", "말하는 언어"), selection: $settings.localeIdentifier) {
          ForEach(VoiceLocale.recommended) { locale in
            Text(locale.nativeName).tag(locale.identifier)
          }
        }
        if model.analyzerEngineSupported {
          Toggle(
            L.t(
              "高精度認識エンジンを使用（macOS 26以降）", "Use the high-accuracy engine (macOS 26+)",
              "使用高精度识别引擎（macOS 26及以上）", "고정밀 인식 엔진 사용（macOS 26 이상）"),
            isOn: $settings.useAnalyzerEngine)
          Text(analyzerEngineCaption)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Toggle(
          L.t(
            "対応している場合はオンデバイス認識を使用", "Prefer on-device recognition when available",
            "支持时优先使用设备端识别", "지원되는 경우 온디바이스 인식 사용"),
          isOn: $settings.preferOnDevice)
        Toggle(
          L.t(
            "「改行」「新しい段落」などの音声コマンドを整形", "Apply spoken commands like \"new line\" and \"new paragraph\"",
            "识别“换行”“新段落”等语音命令", "\"줄바꿈\" \"새 단락\" 등 음성 명령 적용"),
          isOn: $settings.spokenFormattingCommands)
        Text(
          L.t(
            "選択した言語やmacOSの状態によっては、Appleの音声認識サービスへ接続します。高精度エンジンは常にこのMacの中だけで動作します。",
            "Depending on the selected language and macOS state, Apple's speech service may be used over the network. The high-accuracy engine always runs entirely on this Mac.",
            "根据所选语言和macOS状态，可能会连接Apple语音识别服务。高精度引擎始终只在这台Mac上运行。",
            "선택한 언어와 macOS 상태에 따라 Apple 음성 인식 서비스에 연결될 수 있습니다. 고정밀 엔진은 항상 이 Mac 안에서만 동작합니다."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section(L.t("カスタム辞書", "Custom Dictionary", "自定义词典", "사용자 사전")) {
        TextEditor(text: $settings.customVocabulary)
          .font(.body)
          .frame(minHeight: 150)
          .overlay(alignment: .topLeading) {
            if settings.customVocabulary.isEmpty {
              Text(
              L.t(
                "人名、製品名、専門用語を1行に1つ入力", "One name, product, or term per line",
                "每行输入一个人名、产品名或术语", "인명·제품명·전문 용어를 한 줄에 하나씩 입력"))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
        Text(vocabularyCaption)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var privacyTab: some View {
    Form {
      Section(L.t("保存", "Storage", "存储", "저장")) {
        Toggle(
          L.t("音声入力の履歴をこのMacに保存", "Keep dictation history on this Mac", "在这台Mac上保存语音输入历史", "이 Mac에 음성 입력 기록 저장"),
          isOn: $settings.keepHistory)
        Text(
          L.t(
            "初期設定では保存しません。有効にした場合も音声ファイルは保存せず、テキストのみ最大100件をローカルに保管します。",
            "Off by default. Even when enabled, no audio is stored — only text, up to 100 entries, kept locally.",
            "默认不保存。即使启用也不保存音频，仅在本地保留最多100条文本。",
            "기본적으로 저장하지 않습니다. 켜더라도 오디오는 저장하지 않고 텍스트만 최대 100건 로컬에 보관합니다."))
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Button(L.t("履歴を表示", "Show history", "显示历史", "기록 보기")) { model.showHistory() }
          Button(L.t("履歴をすべて削除", "Delete all history", "删除全部历史", "기록 모두 삭제"), role: .destructive) {
            model.history.clear()
          }
            .disabled(model.history.entries.isEmpty)
        }
      }

      Section(L.t("データの扱い", "Data Handling", "数据处理", "데이터 처리")) {
        Label(
          L.t(
            "HS Voice独自のサーバーへ音声やテキストを送信しません", "HS Voice never sends audio or text to its own servers",
            "HS Voice不会向自有服务器发送音频或文本", "HS Voice는 자체 서버로 오디오나 텍스트를 전송하지 않습니다"),
          systemImage: "server.rack")
        Label(
          L.t(
            "カスタム辞書と設定はこのMac内に保存します", "The custom dictionary and settings stay on this Mac",
            "自定义词典和设置保存在这台Mac上", "사용자 사전과 설정은 이 Mac에 저장됩니다"),
          systemImage: "internaldrive")
        Label(
          L.t(
            "Appleの音声認識がネットワークを使用する場合があります", "Apple's speech recognition may use the network",
            "Apple语音识别可能会使用网络", "Apple 음성 인식이 네트워크를 사용할 수 있습니다"),
          systemImage: "network")
      }
    }
    .formStyle(.grouped)
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var permissionsTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(L.t("macOSの権限", "macOS Permissions", "macOS权限", "macOS 권한"))
        .font(.title3.bold())
      Text(
        L.t(
          "システム設定からこの画面へ戻ると、許可状態を自動で更新します。",
          "Permission status refreshes automatically when you return from System Settings.",
          "从系统设置返回此界面时会自动刷新权限状态。",
          "시스템 설정에서 이 화면으로 돌아오면 권한 상태가 자동으로 갱신됩니다."))
        .font(.caption)
        .foregroundStyle(.secondary)

      PermissionRow(
        symbol: "mic.fill",
        title: L.t("マイク", "Microphone", "麦克风", "마이크"),
        detail: L.t("音声を取り込む", "Captures your voice", "采集语音", "음성을 받아들입니다"),
        granted: permissions.microphoneGranted,
        action: permissions.openMicrophoneSettings
      )
      PermissionRow(
        symbol: "waveform.badge.magnifyingglass",
        title: L.t("音声認識", "Speech Recognition", "语音识别", "음성 인식"),
        detail: L.t("音声をテキストに変換する", "Turns speech into text", "将语音转换为文本", "음성을 텍스트로 변환합니다"),
        granted: permissions.speechGranted,
        action: permissions.openSpeechSettings
      )
      PermissionRow(
        symbol: "text.cursor",
        title: L.t("アクセシビリティ", "Accessibility", "辅助功能", "손쉬운 사용"),
        detail: L.t("他のアプリへテキストを入力する", "Types text into other apps", "向其他应用输入文本", "다른 앱에 텍스트를 입력합니다"),
        granted: permissions.accessibilityGranted,
        action: permissions.openAccessibilitySettings
      )
      if !permissions.accessibilityGranted {
        Text(
          L.t(
            "システム設定でオンにしても「許可済み」にならない場合は、一覧の「HS Voice」を「−」で削除し、HS Voiceを再起動してからもう一度オンにしてください。アプリを更新した直後は再設定が必要なことがあります。",
            "If it never shows as granted even after enabling it, remove \"HS Voice\" from the list with the − button, restart HS Voice, and enable it again. This is often needed right after updating the app.",
            "如果开启后仍不显示“已允许”，请在列表中用“−”删除“HS Voice”，重启HS Voice后再重新开启。更新应用后通常需要重新设置。",
            "켜도 '허용됨'으로 표시되지 않으면 목록에서 'HS Voice'를 '−'로 삭제하고 HS Voice를 재시작한 뒤 다시 켜 주세요. 앱 업데이트 직후에는 재설정이 필요할 수 있습니다.")
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
      }

      HStack {
        Button(L.t("マイクと音声認識をリクエスト", "Request Microphone & Speech", "请求麦克风与语音识别", "마이크·음성 인식 요청")) {
          Task { await model.requestPermissions() }
        }
        .buttonStyle(.borderedProminent)
        Spacer()
        Button(L.t("状態を更新", "Refresh status", "刷新状态", "상태 새로고침")) { model.refreshPermissions() }
      }
      .padding(.top, 6)
    }
    .padding(12)
    .disabled(!model.state.allowsConfigurationChanges)
  }
}
