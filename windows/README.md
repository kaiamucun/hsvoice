# HS Voice for Windows

macOS版HS Voiceの姉妹アプリ。「キーを押して話し、任意のWindowsアプリのカーソル位置へ入力する」という同じ使い心地を、Windows 10 / 11向けにC#/.NET 8で新規実装したものです。音声認識はwhisper.cpp(Whisper.net)による**完全ローカル処理**で、音声データがPCの外へ送られることはありません。

設計・計画の背景は `../hsvoice/docs/WINDOWS_VERSION_PLAN.md` を参照してください。

## 主な機能(macOS版との対応)

- タスクトレイ常駐の軽量アプリ(メニューバー常駐の対応)
- 既定は**右Ctrl**を押している間だけ録音(fnキーはWindowsではOSに届かないため)。Ctrl+Space系へ変更可、トグル式も選択可
- whisper.cppによるローカル音声認識(日本語・英語ほか11言語)
- 録音中は画面下の1行オーバーレイに認識中テキストをライブ表示(チャンク推論のため0.5〜2秒遅れの逐次更新)
- 録音中の`Esc`で即キャンセル、55秒の安全停止と残り10秒からのカウントダウン
- 開始・終了のサウンド(設定でオフ可)
- 直前に使っていたアプリのカーソル位置へ、**クリップボードを使わず**SendInputで直接入力(IMEの変換状態も汚しません)
- 自動入力直後8秒間の、同じ入力先に限定した安全な取り消し(Ctrl+Z)
- 「クリップボードへコピーのみ」モード
- 「改行」「新しい段落」「new line」などの音声レイアウトコマンド(macOS版とロジック・テストを共有)
- 最大100語のカスタム辞書(whisperのプロンプトとして誘導)
- オプトインのローカルテキスト履歴(既定は無効・最大100件)。履歴ウィンドウから再入力・コピー・削除
- 初回セットアップガイド(アプリ内からモデルを進捗表示付きでダウンロード。同梱版では自動スキップ)
- サインイン時起動、診断情報コピー(入力本文は含まない)
- 音声を保存しない設計(音声バッファはメモリ上のみ)
- WiXによる単一MSIインストーラ(手動配布・Intune配布兼用、署名対応)

既定値は日本語・右Ctrl・押している間だけ録音・自動入力・履歴オフです。

## 動作環境

- Windows 10 22H2 以降 / Windows 11(x64またはARM64)
- AVX2対応CPU(2013年以降のほぼすべてのx64 CPU)・メモリ8GB以上を推奨
- マイク(Windowsの設定でマイクへのアクセスを許可)
- macOSのような「アクセシビリティ権限」は不要です

## ビルド手順(Windows上で)

1. [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) をインストール
2. ビルドと起動(モデルは初回起動時のセットアップ画面からもダウンロードできます。
   先に用意する場合は `.\scripts\download-model.ps1` を実行するか、ggml形式のモデルを
   `models\` フォルダへ置いてください):

   ```powershell
   dotnet build src\HSVoice.App -c Release
   dotnet run --project src\HSVoice.App -c Release
   ```

3. 配布用の署名付き単一MSIインストーラ(社内配布・Intune用):

   ```powershell
   dotnet tool install --global wix        # 初回のみ
   .\scripts\build-installer.ps1 -BundleModel
   ```

   完成物は `release\HSVoice-1.0.0\HSVoice-Installer-1.0.0-x64.msi`。
   署名・Intune展開・AV許可リストの詳細は `docs\ENTERPRISE_DEPLOYMENT.md` を参照。
   ARM64機(Surface等)向けは `-Arch arm64`。

## テスト

テキスト整形ロジック(macOS版から移植した12テスト)は依存パッケージなしで実行できます:

```powershell
dotnet run --project tests\HSVoice.Core.Tests
```

## 使い方

1. 起動するとタスクトレイに波形アイコンが常駐します(初回はセットアップガイドが開き、モデルのダウンロードを案内します)
2. テキスト欄へカーソルを置く
3. **右Ctrl**を押しながら話し、離す
4. 認識結果がカーソル位置へ入力されます

トレイアイコンの右クリックで、言語と入力方法をその場で切り替えられます。直前のテキストは「もう一度入力」「コピー」で再利用でき、入力直後8秒間は「直前の入力を取り消す」が使えます。

## プロジェクト構成

```
src/HSVoice.Core/     OSに依存しないロジック(macOS版とファイル対応を保つ)
  TextPostProcessor   認識結果の整形・音声レイアウトコマンド(Swift版の忠実な移植)
  Models / Timing     状態機械・選択肢・全タイミング定数
  SettingsStore       %APPDATA%\HS Voice\settings.json
  HistoryStore        オプトイン履歴(最大100件)
src/HSVoice.App/      Windows固有部分
  HotKeyManager       低レベルキーボードフック(CGEventTapの対応物)
  AudioCapture        16kHzモノラル取り込み(NAudio)
  WhisperDictationEngine  whisper.cpp推論(SpeechAnalyzerの対応物)
  TextInsertionService    SendInput Unicode挿入(CGEventの対応物)
  OverlayWindow       1行オーバーレイ / TrayIcon: トレイ常駐
  OnboardingWindow    初回セットアップ(モデルDL) / HistoryWindow: 履歴
Packaging/Package.wxs WiX v4 MSI定義(publish出力を丸ごと取り込み)
scripts/              モデルDL・MSIビルド・検証のPowerShellスクリプト
docs/                 社内展開ガイド(署名・Intune・AV対応)
tests/                オフラインでも動く自前テストランナー
```

## macOS版との既知の違い

- **ライブ表示の遅延**: whisperはチャンク推論のため、録音中の表示は0.5〜2秒遅れで更新されます。最終的な挿入テキストの精度は同等以上です。
- **待機中の表示**: 待機中はオーバーレイを表示せず、トレイアイコンのみです。
- **辞書の効き方**: whisperのinitial promptによる誘導のため、Apple Speechの辞書とは挙動が異なります。
- **管理者権限のアプリ**(昇格したターミナル等)へは入力できません(WindowsのUIPI保護)。その場合は自動的にクリップボードへコピーされます。
- 一部のセキュリティ系・銀行系アプリは合成キー入力をブロックします。「コピーのみ」モードを利用してください。

## 未着手(今後の作業)

- Windows on ARMの実機検証
- 会社の証明書での署名と、ウイルス対策ソフトの許可リスト登録(docs\ENTERPRISE_DEPLOYMENT.md参照)

## 重要な注意

このコードはLinux環境で書かれ、ロジック層のテスト(12件)と型チェックまでは検証済みですが、**Windows実機でのビルド・動作確認はまだ行われていません**。最初のビルドで軽微な修正(特にWhisper.net APIの版差、WiXのバージョン差)が必要になる可能性があります。
