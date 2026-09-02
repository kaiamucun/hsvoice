import AppKit
import SwiftUI

/// The sidebar sections of the settings window.
enum SettingsPage: String, CaseIterable, Identifiable {
  case general
  case shortcuts
  case recognition
  case dictionary
  case replacements
  case ai
  case privacy
  case permissions
  case support

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: return L.t("一般", "General", "通用", "일반")
    case .shortcuts: return L.t("ショートカット", "Shortcuts", "快捷键", "단축키")
    case .recognition: return L.t("音声認識", "Recognition", "语音识别", "음성 인식")
    case .dictionary: return L.t("辞書", "Dictionary", "词典", "사전")
    case .replacements: return L.t("置換", "Replacements", "替换", "치환")
    case .ai: return L.t("AI整形", "AI Polish", "AI润色", "AI 다듬기")
    case .privacy: return L.t("履歴とプライバシー", "History & Privacy", "历史与隐私", "기록과 프라이버시")
    case .permissions: return L.t("権限", "Permissions", "权限", "권한")
    case .support: return L.t("サポート", "Support", "支持", "지원")
    }
  }

  var subtitle: String {
    switch self {
    case .general:
      return L.t(
        "録音の始め方と、認識したテキストの入れ方。", "How recording starts and where the text goes.",
        "如何开始录音，以及文字如何输入。", "녹음 시작 방식과 텍스트 입력 방식.")
    case .shortcuts:
      return L.t(
        "音声入力を操作するキーとマウスボタン。", "The keys and mouse buttons that drive dictation.",
        "用于控制语音输入的按键和鼠标按钮。", "음성 입력을 조작하는 키와 마우스 버튼.")
    case .recognition:
      return L.t(
        "話す言語、認識エンジン、使用するマイク。", "Spoken language, recognition engine, and microphone.",
        "所说语言、识别引擎和使用的麦克风。", "말하는 언어, 인식 엔진, 사용하는 마이크.")
    case .dictionary:
      return L.t(
        "人名・製品名・専門用語を正しい表記で入力します。",
        "Names, products, and jargon typed with the right spelling.",
        "以正确写法输入人名、产品名和专业术语。", "인명·제품명·전문 용어를 올바른 표기로 입력합니다.")
    case .replacements:
      return L.t(
        "ひと言で、登録した文章やアドレスを入力します。",
        "Say a short phrase, get the full text.",
        "说一个词，输入整段文字或地址。", "한마디로 등록한 문장이나 주소를 입력합니다.")
    case .ai:
      return L.t(
        "Apple Intelligenceで、入力前に文章を仕上げます。",
        "Polish the transcript with Apple Intelligence before it is inserted.",
        "在输入前用Apple Intelligence润色文本。", "Apple Intelligence로 입력 전에 문장을 다듬습니다.")
    case .privacy:
      return L.t(
        "このMacに何を残すか。", "What stays on this Mac.", "这台Mac上保留什么。", "이 Mac에 무엇을 남길지.")
    case .permissions:
      return L.t(
        "macOSの権限の状態。", "The state of the macOS permissions.", "macOS权限状态。", "macOS 권한 상태.")
    case .support:
      return L.t(
        "セットアップの再表示と、社内サポート用の診断情報。",
        "Show setup again, and diagnostics for in-house support.",
        "重新显示设置向导，以及用于内部支持的诊断信息。", "설정 안내 다시 보기와 사내 지원용 진단 정보.")
    }
  }

  var symbol: String {
    switch self {
    case .general: return "gearshape"
    case .shortcuts: return "keyboard"
    case .recognition: return "waveform"
    case .dictionary: return "character.book.closed"
    case .replacements: return "arrow.left.arrow.right"
    case .ai: return "sparkles"
    case .privacy: return "hand.raised"
    case .permissions: return "checkmark.shield"
    case .support: return "questionmark.circle"
    }
  }
}

struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var settings: SettingsStore
  @State private var selection: SettingsPage? = .general

  init(model: AppModel) {
    self.model = model
    _settings = ObservedObject(wrappedValue: model.settings)
  }

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 250)
    } detail: {
      detail
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 860, minHeight: 600)
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

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 40, height: 40)
        VStack(alignment: .leading, spacing: 1) {
          Text("HS Voice").font(.headline)
          Text(model.versionDisplay).font(.caption2).foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 6)

      List(selection: $selection) {
        ForEach(SettingsPage.allCases) { page in
          Label(page.title, systemImage: page.symbol)
            .tag(page)
        }
      }
      .listStyle(.sidebar)

      HStack(spacing: 6) {
        Circle().fill(.green).frame(width: 7, height: 7)
        Text(L.t("このMacの中だけで処理", "Processed only on this Mac", "仅在这台Mac上处理", "이 Mac 안에서만 처리"))
          .font(.caption)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Capsule().fill(Color.primary.opacity(0.06)))
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
  }

  @ViewBuilder
  private var detail: some View {
    switch selection ?? .general {
    case .general: GeneralSettingsPage(model: model)
    case .shortcuts: ShortcutSettingsPage(model: model)
    case .recognition: RecognitionSettingsPage(model: model)
    case .dictionary: DictionarySettingsPage(model: model)
    case .replacements: ReplacementSettingsPage(model: model)
    case .ai: AISettingsPage(model: model)
    case .privacy: PrivacySettingsPage(model: model)
    case .permissions: PermissionSettingsPage(model: model)
    case .support: SupportSettingsPage(model: model)
    }
  }
}

// MARK: - Shared building blocks

/// Page title and one-line subtitle, with optional controls on the right.
struct SettingsPageHeader<Trailing: View>: View {
  let page: SettingsPage
  let trailing: Trailing

  init(_ page: SettingsPage, @ViewBuilder trailing: () -> Trailing) {
    self.page = page
    self.trailing = trailing()
  }

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        Text(page.title).font(.title2.bold())
        Text(page.subtitle).font(.callout).foregroundStyle(.secondary)
      }
      Spacer()
      trailing
    }
    .padding(.horizontal, 28)
    .padding(.top, 26)
    .padding(.bottom, 2)
  }
}

extension SettingsPageHeader where Trailing == EmptyView {
  init(_ page: SettingsPage) {
    self.init(page) { EmptyView() }
  }
}

/// Header plus a grouped form, the layout every settings page shares.
struct SettingsPageScaffold<Trailing: View, Content: View>: View {
  let page: SettingsPage
  let trailing: Trailing
  let content: Content

  init(
    _ page: SettingsPage, @ViewBuilder trailing: () -> Trailing,
    @ViewBuilder content: () -> Content
  ) {
    self.page = page
    self.trailing = trailing()
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SettingsPageHeader(page) { trailing }
      Form { content }
        .formStyle(.grouped)
    }
  }
}

extension SettingsPageScaffold where Trailing == EmptyView {
  init(_ page: SettingsPage, @ViewBuilder content: () -> Content) {
    self.init(page, trailing: { EmptyView() }, content: content)
  }
}

/// A row label: the setting's name with its one-line explanation underneath,
/// so the caption sits next to the control it describes.
struct SettingLabel: View {
  let title: String
  var detail: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
      if let detail, !detail.isEmpty {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 2)
  }
}

struct SettingCaption: View {
  let text: String
  var isWarning = false

  init(_ text: String, isWarning: Bool = false) {
    self.text = text
    self.isWarning = isWarning
  }

  var body: some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// The small "Reset to defaults" link at the end of a page.
struct ResetDefaultsButton: View {
  let action: () -> Void

  var body: some View {
    HStack {
      Spacer()
      Button(L.t("デフォルトにリセット", "Reset to defaults", "重置为默认", "기본값으로 재설정"), action: action)
        .buttonStyle(.link)
        .font(.caption)
    }
  }
}
