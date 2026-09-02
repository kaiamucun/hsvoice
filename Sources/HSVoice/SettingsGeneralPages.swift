import AppKit
import SwiftUI

// MARK: - General

struct GeneralSettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  var body: some View {
    SettingsPageScaffold(.general) {
      Section {
        hintCard
      }

      Section(L.t("音声入力", "Dictation", "语音输入", "음성 입력")) {
        Picker(selection: $settings.activationMode) {
          ForEach(ActivationMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        } label: {
          SettingLabel(
            title: L.t("起動方法", "Activation", "启动方式", "시작 방식"),
            detail: settings.activationMode.detail)
        }

        Picker(
          selection: Binding(
            get: { settings.insertionMode },
            set: { model.setInsertionMode($0) }
          )
        ) {
          ForEach(InsertionMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        } label: {
          SettingLabel(
            title: L.t("入力方法", "Insertion", "输入方式", "입력 방식"),
            detail: settings.insertionMode.detail)
        }

        Toggle(isOn: $settings.soundFeedback) {
          SettingLabel(
            title: L.t("開始・終了のサウンドを再生", "Play start / stop sounds", "播放开始/结束提示音", "시작·종료 사운드 재생"),
            detail: L.t(
              "録音の開始と終了を短い音で知らせます。", "A short cue marks the start and the end of a recording.",
              "以短促提示音标记录音的开始和结束。", "짧은 소리로 녹음의 시작과 끝을 알립니다."))
        }

        Toggle(isOn: $settings.showIdleIndicator) {
          SettingLabel(
            title: L.t(
              "待機中も画面下に小さなアイコンを表示", "Show the small idle icon at the bottom of the screen",
              "待机时在屏幕底部显示小图标", "대기 중에도 화면 하단에 작은 아이콘 표시"),
            detail: L.t(
              "録音中はこのアイコンが広がり、認識中のテキストをライブ表示します。",
              "While recording it expands to show the live transcript.",
              "录音时该图标会展开并实时显示识别文本。", "녹음 중에는 이 아이콘이 펼쳐져 인식 중인 텍스트를 표시합니다."))
        }
      }

      Section("Mac") {
        Toggle(
          isOn: Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
          )
        ) {
          SettingLabel(
            title: L.t("ログイン時にHS Voiceを起動", "Launch HS Voice at login", "登录时启动HS Voice", "로그인 시 HS Voice 시작"),
            detail: L.t(
              "Macの起動時にバックグラウンドで起動し、すぐに使えるようにします。",
              "Starts in the background when you log in, ready to use.",
              "登录时在后台启动，随时可用。", "로그인 시 백그라운드에서 시작해 바로 사용할 수 있게 합니다."))
        }
        if let error = settings.launchAtLoginError {
          Text(error).font(.caption).foregroundStyle(.red)
        }
      }

      Section {
        ResetDefaultsButton { settings.resetGeneralDefaults() }
      }
    }
    .disabled(!model.state.allowsConfigurationChanges)
  }

  /// The one thing a new user needs to know, kept at the top of the first page.
  private var hintCard: some View {
    HStack(spacing: 14) {
      Image(systemName: "waveform.circle.fill")
        .font(.system(size: 30))
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          ShortcutKeyCapsView(labels: settings.shortcutChoice.keyLabels)
          Text(activationHint)
        }
        Text(
          L.t(
            "どのアプリのテキスト欄でも使えます。認識結果はカーソル位置に入力されます。",
            "Works in any app's text field. The result is typed at the cursor.",
            "可在任何应用的文本框中使用，识别结果输入到光标位置。",
            "어떤 앱의 텍스트 칸에서도 사용할 수 있습니다. 결과는 커서 위치에 입력됩니다."))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 6) {
        Image(systemName: model.state.symbolName)
        Text(model.state.title)
      }
      .font(.caption.weight(.medium))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
    .padding(.vertical, 6)
  }

  private var activationHint: String {
    switch settings.activationMode {
    case .hold:
      return L.t("を押しながら話します", "— hold it and speak", "按住并说话", "를 누른 채 말하세요")
    case .toggle:
      return L.t(
        "を押して話し、もう一度押すと入力されます", "— press, speak, press again to insert",
        "按下说话，再按一次输入", "를 눌러 말하고, 다시 누르면 입력됩니다")
    case .auto:
      return L.t(
        "を押しながら話すか、短く押してハンズフリーで話します", "— hold to talk, or tap for hands-free",
        "按住说话，或短按进入免提", "를 누른 채 말하거나, 짧게 눌러 핸즈프리로 말하세요")
    }
  }
}

// MARK: - Shortcuts

struct ShortcutSettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  var body: some View {
    SettingsPageScaffold(.shortcuts) {
      Section(L.t("キーバインド", "Keybindings", "快捷键", "키 바인딩")) {
        HStack(alignment: .center) {
          SettingLabel(
            title: L.t("音声入力を開始", "Start dictation", "开始语音输入", "음성 입력 시작"),
            detail: settings.activationMode.detail)
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
        if !model.shortcutAvailable {
          Label(shortcutWarning, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }

        Toggle(
          isOn: Binding(
            get: { settings.repeatShortcutEnabled },
            set: { model.setRepeatShortcutEnabled($0) }
          )
        ) {
          SettingLabel(
            title: L.t("前回の音声入力を再入力", "Re-insert the last dictation", "重新输入上次的语音内容", "마지막 음성 입력 다시 입력"),
            detail: L.t(
              "最後の音声入力テキストをカーソル位置にもう一度入力します（メニューバーの「直前の入力」と同じ動作）。",
              "Types your last dictation at the cursor again (same as “Last dictation” in the menu bar).",
              "将上次语音输入的文本再次输入到光标位置（与菜单栏“上次输入”相同）。",
              "마지막 음성 입력 텍스트를 커서 위치에 다시 입력합니다（메뉴 막대「마지막 입력」과 동일）."))
        }
        .disabled(model.isCapturingShortcut)
        if settings.repeatShortcutEnabled {
          HStack(alignment: .center) {
            SettingLabel(title: L.t("再入力ショートカット", "Re-insert shortcut", "重新输入快捷键", "재입력 단축키"))
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
        }

        HStack(alignment: .center) {
          SettingLabel(
            title: L.t("録音をキャンセル", "Cancel recording", "取消录音", "녹음 취소"),
            detail: L.t(
              "録音中に押すと、認識したテキストを破棄します。", "Press while recording to discard the transcript.",
              "录音时按下将丢弃识别文本。", "녹음 중에 누르면 인식된 텍스트를 버립니다."))
          Spacer()
          ShortcutKeyCapsView(labels: ["esc"])
        }

        HStack(alignment: .center) {
          SettingLabel(
            title: L.t("安全停止", "Safety stop", "安全停止", "안전 정지"),
            detail: L.t(
              "1回の音声入力は55秒で自動的に終了します。残り10秒からカウントダウンを表示します。長文は段落ごとに分けると安定します。",
              "Each dictation stops on its own after 55 seconds, with a countdown for the last 10. Long texts are steadier paragraph by paragraph.",
              "每次语音输入将在55秒后自动结束，最后10秒显示倒计时。长文本建议分段输入。",
              "한 번의 음성 입력은 55초 후 자동으로 종료되며 마지막 10초는 카운트다운을 표시합니다. 긴 글은 문단별로 나누면 안정적입니다."))
          Spacer()
          Text("55 s").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
        }

        SettingCaption(
          L.t(
            "「変更…」を押して、使いたいキーの組み合わせやマウスボタンをそのまま押すと登録できます（例: ⌘⇧V、マウスのサイドボタン。M3=中央、M4/M5=サイド）。",
            "Press “Change…”, then type the key combination or click the mouse button you want (e.g. ⌘⇧V, or a side button; M3 = middle, M4/M5 = side).",
            "点按“更改…”后直接按下想使用的组合键或鼠标按钮即可登记（例如 ⌘⇧V、鼠标侧键。M3=中键、M4/M5=侧键）。",
            "「변경…」을 누른 뒤 사용할 키 조합이나 마우스 버튼을 그대로 누르면 등록됩니다（예: ⌘⇧V, 마우스 사이드 버튼. M3=가운데, M4/M5=사이드）."))
      }

      Section {
        ResetDefaultsButton {
          model.setShortcut(.functionKey)
          model.setRepeatShortcutEnabled(false)
          model.setRepeatShortcut(.defaultRepeatShortcut)
        }
      }
    }
    .disabled(!model.state.allowsConfigurationChanges)
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
}

// MARK: - AI polish

struct AISettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  var body: some View {
    SettingsPageScaffold(.ai) {
      Section(L.t("AI整形・要約", "AI Polish & Summarize", "AI润色与摘要", "AI 다듬기·요약")) {
        if model.refinementSupported {
          Toggle(isOn: $settings.aiRefinementEnabled) {
            SettingLabel(
              title: L.t(
                "入力前にAIで文章を仕上げる", "Polish text with AI before inserting",
                "输入前用AI润色文本", "입력 전에 AI로 문장 다듬기"),
              detail: L.t(
                "Apple Intelligenceがフィラーを取り除き、読みやすい文章に整えます。処理はこのMacの中だけで行われます。",
                "Apple Intelligence removes fillers and tidies the text. Processing happens entirely on this Mac.",
                "Apple Intelligence会去除口头语并整理文本。处理完全在这台Mac上进行。",
                "Apple Intelligence가 군말을 제거하고 읽기 쉬운 문장으로 정리합니다. 처리는 이 Mac 안에서만 이루어집니다."))
          }
          if settings.aiRefinementEnabled {
            Picker(selection: $settings.aiRefinementMode) {
              ForEach(RefinementMode.allCases) { mode in
                Text(mode.label).tag(mode)
              }
            } label: {
              SettingLabel(
                title: L.t("処理モード", "Mode", "处理模式", "처리 모드"),
                detail: settings.aiRefinementMode.detail)
            }
          }
          SettingCaption(refinementCaption, isWarning: refinementCaptionIsWarning)
        } else {
          SettingCaption(
            L.t(
              "AIによる整形・要約は、macOS 26以降のApple Intelligence対応Macで利用できます。",
              "AI polish & summarize requires macOS 26 or later on an Apple Intelligence capable Mac.",
              "AI润色与摘要需要macOS 26或更高版本，且Mac支持Apple Intelligence。",
              "AI 다듬기·요약은 macOS 26 이상의 Apple Intelligence 지원 Mac에서 사용할 수 있습니다."))
        }
      }

      Section(L.t("カスタム指示", "Custom Instructions", "自定义指令", "사용자 지침")) {
        ZStack(alignment: .topLeading) {
          TextEditor(text: $settings.aiCustomInstructions)
            .font(.body)
            .frame(minHeight: 120)
          if settings.aiCustomInstructions.isEmpty {
            Text(
              L.t(
                "例: 「Slackではカジュアルな文体にする」「箇条書きは使わない」「英語の固有名詞はそのまま残す」",
                "e.g. “Casual tone in Slack”, “Never use bullet points”, “Keep English names as they are”",
                "例如：“在Slack中使用随意语气”“不要使用项目符号”“保留英文专有名词”",
                "예: 「Slack에서는 캐주얼한 문체」「글머리 기호는 사용하지 않기」「영어 고유명사는 그대로 두기」"))
              .foregroundStyle(.tertiary)
              .padding(.top, 8)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
        SettingCaption(
          L.t(
            "文体や書式の好みを自由に書けます。AI整形が有効なときに、上のルールより優先して適用されます。辞書の「正しい表記」も自動でAIに伝えます。",
            "Describe the tone and formatting you want. Applied on top of the mode's rules whenever AI polish is on. Dictionary spellings are passed to the model automatically.",
            "可自由描述文体和格式偏好。开启AI润色时，优先于上面的规则应用。词典中的“正确写法”也会自动传给AI。",
            "문체와 서식 취향을 자유롭게 적을 수 있습니다. AI 다듬기가 켜져 있을 때 위 규칙보다 우선 적용됩니다. 사전의 「올바른 표기」도 자동으로 AI에 전달됩니다."))
      }
      .disabled(!model.refinementSupported)
    }
    .disabled(!model.state.allowsConfigurationChanges)
  }

  private var refinementCaption: String {
    switch RefinementService.availability() {
    case .available:
      return L.t(
        "AI処理の分だけ、入力までに数秒かかることがあります。うまく仕上がらなかった場合は認識したままの文章を入力します。",
        "AI adds a few seconds before insertion; if it can't improve the text, the raw transcript is inserted.",
        "AI处理会使输入多花几秒；若处理不理想，将输入原始识别文本。",
        "AI 처리만큼 입력까지 몇 초 걸릴 수 있으며, 잘 다듬지 못한 경우 인식된 원문을 입력합니다.")
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
}

// MARK: - History & privacy

struct PrivacySettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @ObservedObject private var history: HistoryStore

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
    _history = ObservedObject(wrappedValue: model.history)
  }

  var body: some View {
    SettingsPageScaffold(.privacy) {
      Section(L.t("履歴", "History", "历史", "기록")) {
        Toggle(isOn: $settings.keepHistory) {
          SettingLabel(
            title: L.t("音声入力の履歴をこのMacに保存", "Keep dictation history on this Mac", "在这台Mac上保存语音输入历史", "이 Mac에 음성 입력 기록 저장"),
            detail: L.t(
              "初期設定では保存しません。有効にした場合も音声ファイルは保存せず、テキストのみ最大100件をローカルに保管します。",
              "Off by default. Even when enabled, no audio is stored — only text, up to 100 entries, kept locally.",
              "默认不保存。即使启用也不保存音频，仅在本地保留最多100条文本。",
              "기본적으로 저장하지 않습니다. 켜더라도 오디오는 저장하지 않고 텍스트만 최대 100건 로컬에 보관합니다."))
        }
        HStack {
          Button(L.t("履歴を表示", "Show history", "显示历史", "기록 보기")) { model.showHistory() }
          Button(L.t("履歴をすべて削除", "Delete all history", "删除全部历史", "기록 모두 삭제"), role: .destructive) {
            history.clear()
          }
          .disabled(history.entries.isEmpty)
          Spacer()
          Text(
            L.t("\(history.entries.count)件", "\(history.entries.count) entries", "\(history.entries.count)条", "\(history.entries.count)건")
          )
          .font(.caption)
          .foregroundStyle(.secondary)
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
            "辞書・置換・設定はこのMac内に保存します", "The dictionary, replacements, and settings stay on this Mac",
            "词典、替换和设置保存在这台Mac上", "사전·치환·설정은 이 Mac에 저장됩니다"),
          systemImage: "internaldrive")
        Label(
          L.t(
            "AI整形はApple Intelligenceでこのマックの中だけで処理します", "AI polish runs on this Mac only, via Apple Intelligence",
            "AI润色通过Apple Intelligence仅在这台Mac上处理", "AI 다듬기는 Apple Intelligence로 이 Mac 안에서만 처리합니다"),
          systemImage: "sparkles")
        Label(
          L.t(
            "Appleの音声認識がネットワークを使用する場合があります（高精度エンジンは常にオンデバイス）",
            "Apple's speech recognition may use the network (the high-accuracy engine is always on-device)",
            "Apple语音识别可能会使用网络（高精度引擎始终在设备端）",
            "Apple 음성 인식이 네트워크를 사용할 수 있습니다（고정밀 엔진은 항상 온디바이스）"),
          systemImage: "network")
      }
    }
    .disabled(!model.state.allowsConfigurationChanges)
  }
}

// MARK: - Permissions

struct PermissionSettingsPage: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var permissions: PermissionsManager

  init(model: AppModel) {
    self.model = model
    _permissions = ObservedObject(wrappedValue: model.permissions)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SettingsPageHeader(.permissions) {
        Button(L.t("状態を更新", "Refresh status", "刷新状态", "상태 새로고침")) { model.refreshPermissions() }
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
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

          Button(L.t("マイクと音声認識をリクエスト", "Request Microphone & Speech", "请求麦克风与语音识别", "마이크·음성 인식 요청")) {
            Task { await model.requestPermissions() }
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 6)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
      }
    }
    .disabled(!model.state.allowsConfigurationChanges)
  }
}

// MARK: - Support

struct SupportSettingsPage: View {
  @ObservedObject var model: AppModel

  var body: some View {
    SettingsPageScaffold(.support) {
      Section(L.t("はじめから", "Start over", "重新开始", "처음부터")) {
        HStack {
          SettingLabel(
            title: L.t("セットアップをもう一度表示", "Show setup again", "重新显示设置向导", "설정 안내 다시 보기"),
            detail: L.t(
              "権限の案内と最初の使い方をもう一度表示します。", "Shows the permission guide and the first steps again.",
              "再次显示权限指引和入门步骤。", "권한 안내와 처음 사용법을 다시 표시합니다."))
          Spacer()
          Button(L.t("表示", "Show", "显示", "표시")) { model.showOnboarding() }
        }
      }

      Section(L.t("社内サポート", "In-house support", "内部支持", "사내 지원")) {
        HStack {
          SettingLabel(
            title: L.t("診断情報をコピー", "Copy diagnostics", "复制诊断信息", "진단 정보 복사"),
            detail: L.t(
              "問い合わせの際に貼り付けてください。音声、入力本文、辞書内容、ユーザー名、端末名は含まれません。",
              "Paste this into your support request. It never includes audio, dictated text, dictionary contents, your user name, or the device name.",
              "咨询时请粘贴此信息。不包含音频、输入内容、词典内容、用户名或设备名。",
              "문의 시 붙여 넣어 주세요. 오디오, 입력한 본문, 사전 내용, 사용자 이름, 기기 이름은 포함되지 않습니다."))
          Spacer()
          Button(L.t("コピー", "Copy", "复制", "복사")) { model.copyDiagnostics() }
        }
        HStack {
          SettingLabel(title: L.t("バージョン", "Version", "版本", "버전"))
          Spacer()
          Text(model.versionDisplay).foregroundStyle(.secondary)
        }
      }
    }
  }
}
