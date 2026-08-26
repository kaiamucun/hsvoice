# HS Voice Windows版 設計・計画書

作成日: 2026-08-26 / 対象OS: Windows 10 22H2以降・Windows 11

## 1. 結論(先に要点)

現行のHS VoiceはmacOS専用技術(SpeechAnalyzer / CGEvent / Carbon / SwiftUI / TCC)の上に構築されており、**コード移植では動かない**。Windows対応は「移植」ではなく、**同じ設計思想を持つ姉妹アプリの新規開発**になる。

再利用できるのは、UI・OS層ではなく「仕様と挙動」である。押している間だけ録音、カーソル位置への直接キーストローク挿入(クリップボード非使用)、最小限の1行オーバーレイ、音声レイアウトコマンド、履歴オプトイン、音声を保存しない設計——これらはすべてWindows版でも再現可能。

音声認識はユーザー決定どおり **whisper.cpp(完全ローカル)** を採用する。

## 2. 機能対応表(macOS版 → Windows版)

| macOS版の機能 | macOSでの実装 | Windowsでの実現方法 | 忠実度 |
|---|---|---|---|
| 音声認識(日本語ほか多言語) | SpeechAnalyzer / Apple Speech | whisper.cpp(Whisper.netバインディング) | ◎ 精度は同等以上が期待できる |
| ライブ認識テキスト表示 | SpeechAnalyzerのvolatile結果 | VAD+チャンク分割の逐次推論で擬似ライブ表示 | △ 真のストリーミングではなく0.5〜2秒遅れの逐次更新になる(§6参照) |
| グローバルホットキー(fnキー) | Carbon / CGEventTap | 低レベルキーボードフック(WH_KEYBOARD_LL)+RegisterHotKey | ○ fnキーはWindowsではOSに届かないため既定キーを変更(§5参照) |
| 押している間だけ録音/トグル | flagsChanged監視 | フックでkeydown/keyup検出 | ◎ |
| カーソル位置への直接挿入 | CGEventキーストローク | SendInput(KEYEVENTF_UNICODE) | ◎ クリップボード非使用の方針を維持。IMEを経由せず確定文字列として入る |
| 挿入直後の安全な取り消し | 同一入力先限定・8秒 | 前面ウィンドウハンドル照合+Backspace送出で同一仕様を再現 | ◎ |
| 1行オーバーレイ(作業中モニター) | SwiftUI+NSWindow | WPF最前面ボーダーレスウィンドウ(Per-Monitor DPI v2対応) | ◎ |
| メニューバー常駐 | NSStatusItem | タスクトレイ(NotifyIcon)+ポップアップメニュー | ◎ 置き場所がメニューバー→トレイに変わるのみ |
| 権限オンボーディング | TCC(マイク・音声認識・アクセシビリティ) | マイクのプライバシー設定のみ。アクセシビリティ相当の許可は不要 | ◎ Windowsの方がシンプルになる |
| escキャンセル・55秒上限・カウントダウン | アプリ内ロジック | そのまま同一仕様で実装(whisperにはOS由来の時間制限がないため、上限は任意設定にできる) | ◎ |
| 音声レイアウトコマンド(「改行」等) | TextPostProcessor(純ロジック) | **仕様をそのまま移植**(SwiftのロジックをC#へ書き直し。既存テストケースも移植) | ◎ |
| カスタム辞書(最大100語) | 認識エンジンへのヒント | whisperのinitial_prompt+後処理置換で近似 | ○ 効き方は同一ではない |
| 開始・終了サウンド/効果音オフ | NSSound | System.Media / WASAPI再生 | ◎ |
| ログイン時起動 | SMAppService | Runレジストリキーまたはスタートアップタスク | ◎ |
| 設定・履歴(オプトイン)・診断コピー | UserDefaults等 | %APPDATA%\HSVoice\ にJSON保存。仕様同一 | ◎ |
| 音声を保存しない設計 | メモリ内処理 | 同一方針(音声バッファはメモリのみ、モデル推論後即破棄) | ◎ |
| Universal(AppleSilicon/Intel) | universal binary | win-x64 + win-arm64 の2ビルド | ◎ |
| 単一インストーラ(.pkg) | productbuild | MSI(WiX)または単一EXE(Inno Setup)+Authenticode署名 | ◎ §7参照 |

## 3. 技術構成(推奨スタック)

- **言語/ランタイム**: C# / .NET 8 LTS(self-contained配布で利用者の.NETインストール不要)
- **UI**: WPF(トレイ常駐+設定ウィンドウ+オーバーレイ)。WinUI 3はトレイ常駐・低レベルフックとの相性が悪いため不採用
- **音声認識**: whisper.cpp を Whisper.net 経由で利用
  - 既定モデル: **large-v3-turbo の量子化版(q5_0、約570MB)** — 日本語精度と速度のバランスが最良
  - 低スペックPC向けフォールバック: small(約470MB)を設定で選択可
  - 実行: CPU(AVX2)を基準線とし、対応GPUがあればVulkan/CUDAを自動利用
  - モデルはインストーラ同梱(社内配布なのでサイズより「ダウンロード不要」を優先)
- **音声入力**: WASAPI(NAudio)16kHzモノラル取り込み+Silero VAD(発話区間検出)
- **キー入力挿入**: SendInput + KEYEVENTF_UNICODE(サロゲートペア対応、絵文字・全Unicode可)
- **グローバルキー監視**: WH_KEYBOARD_LL フック(押している間モード用)+RegisterHotKey(トグル用)

## 4. アーキテクチャ

macOS版と同じ責務分割を踏襲し、ファイル対応を1対1に保つ(保守時に両OS版を並べて読めるようにする):

```
AppModel.swift            → AppModel.cs            (状態機械: idle/recording/inserting)
AnalyzerDictationEngine   → WhisperDictationEngine (VAD+チャンク推論)
GlobalHotKeyManager       → HotKeyManager          (LLフック)
TextInsertionService      → TextInsertionService   (SendInput)
TextPostProcessor         → TextPostProcessor      (ロジック・テストごと移植)
RecordingOverlayView      → OverlayWindow (WPF)
MenuBarView               → TrayMenu
SettingsStore/HistoryStore→ 同名 (JSON永続化)
```

## 5. ホットキーの既定値(macOSと異なる点)

fnキーはWindowsではキーボードファームウェア内で処理されOSに届かないため使えない。候補:

1. **右Ctrl(推奨・既定値)** — 押している間だけ録音。単独押しでの誤爆が少なく、日本語キーボードにも必ず存在する
2. CapsLock — 場所は良いがIME切替に使う社員がいる可能性
3. F13〜/任意キー — 外付けキーボード向けの設定項目として提供

Win+HはWindows標準音声入力と衝突するため使わない。macOS版同様、初回起動時に変更不要で使い始められる既定値とし、設定でSpace系の組み合わせ等へ変更可能にする。

## 6. 最大の品質差分: ライブ表示の挙動(正直な注意点)

SpeechAnalyzerは真のストリーミング認識で、話しながらほぼ即時に文字が更新される。whisperはチャンク単位の推論のため、Windows版のオーバーレイ表示は「0.5〜2秒遅れで文節ごとに追記される」動きになる。**最終的な挿入テキストの精度は同等以上だが、録音中の見た目の即時性は一段劣る。**

緩和策: VADで無音区切りごとに即推論(体感遅延を最小化)、オーバーレイに波形/レベルメーターを常時表示して「聞こえている」ことを示す。この差分は社内リリースノートに明記することを推奨。

## 7. 配布・企業展開

- **署名**: Authenticode(EVまたはOV証明書)。未署名EXEはSmartScreenで警告が出るため、社内配布でも署名は必須扱いとする(macOS版の公証に相当)
- **インストーラ**: 単一MSI(WiX Toolset)。手動配布とIntune/MDM配布で同一ファイルを使用 — macOS版の「単一PKG」方針と同じ
- **Intune展開**: 必須アプリとして割当。PPPC相当の事前許可プロファイルは不要(マイク許可は既定で企業ポリシー制御可能)
- **アンインストール**: 標準の「アプリと機能」から。%APPDATA%の設定・履歴は削除時に消去するか選択

## 8. 開発フェーズと目安工数

| フェーズ | 内容 | 完了条件 | 目安 |
|---|---|---|---|
| P0: PoC | マイク取込→whisper日本語認識→メモ帳へSendInput挿入の一本道 | 「話した日本語がメモ帳に入る」動画が撮れる | 2〜3日 |
| P1: コア | 状態機械・ホットキー(押下/トグル)・オーバーレイ・esc・取り消し | macOS版の基本操作フローと同一の体験 | 1〜2週 |
| P2: 同等機能 | 言語切替・レイアウトコマンド・辞書・履歴・設定・診断・自動起動 | 機能対応表の◎項目がすべて動作 | 1〜2週 |
| P3: 配布 | 署名MSI・ARM64ビルド・Intune検証・利用マニュアルWindows版 | クリーンなWin10/11実機でインストール→即使用可能 | 1週 |

前提: Windows 10 22H2とWindows 11の実機(またはVM)各1台。**このクラウド環境ではWindowsのビルド・動作確認ができないため、P0以降は必ずWindows実機での検証を伴う。**

## 9. リスク一覧

- 管理者権限で起動されたアプリ(昇格したターミナル等)へはSendInputが届かない(UIPI)。macOS版に同種の制約はないため、マニュアルに明記する
- 一部の銀行系・セキュリティ系アプリはキーストローク注入をブロックする。フォールバックとして「クリップボードへコピーのみ」モード(macOS版に既存の仕様)を同様に用意する
- LLキーボードフックはアンチウイルスに検知されることがある → 署名+社内AV除外申請で対処
- 低スペックPC(AVX2非対応の古いWin10機)ではwhisperが実用速度に届かない可能性 → smallモデル+動作要件の明記
- Windows on ARM(Surface等)はwhisper.cppのARM64ビルド検証が別途必要

## 10. 判断ポイント

開発着手前に決めること:

1. 既定ホットキー(本書は右Ctrlを推奨)
2. モデル同梱かダウンロードか(本書は同梱を推奨 → インストーラ約700MB)
3. 対象PCの最低スペック(目安: AVX2対応CPU・メモリ8GB)
4. P0のPoCを見てからP1以降を判断する、という段階進行で良いか
