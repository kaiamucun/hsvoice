# HS Voice

HS Voiceは、Aqua Voiceの「キーを押して話し、任意のMacアプリへ入力する」という使い心地を参考にした、社内配布向けのネイティブmacOS音声入力アプリです。Aqua Voiceの製品名・モデル・画面を複製したものではありません。

## 主な機能

- メニューバー常駐の軽量なSwiftUIアプリ
- `fn`キー（初期設定）と4種類のSpace系フォールバック
- キーを押している間、またはトグル式で録音
- Apple Speechによるライブ音声認識と自動句読点
- メニューバーから話す言語と入力方法をすぐに切り替え
- 「改行」「新しい段落」「new line」などの音声レイアウトコマンド
- 録音時間表示と55秒の安全停止
- 直前に使用していたアプリのカーソル位置へ自動入力
- 直前のテキストをワンクリックで再入力・コピー
- 自動入力直後8秒間の、同じ入力先に限定した安全な取り消し
- アクセシビリティ権限が不要な「クリップボードへコピーのみ」モード
- 日本語、英語、中国語、韓国語、フランス語などの言語選択
- 最大100語のカスタム辞書
- 音声を保存しない設計
- オプトインのローカルテキスト履歴（初期設定は無効）
- ログイン時起動
- 入力本文を含まない社内サポート用診断情報コピー
- Apple Silicon／Intel対応のUniversalアプリ
- 社内配布用の単一`.pkg`インストーラを再現可能にビルド

## 動作環境

- macOS 14 Sonoma以降
- Apple Siliconまたは64-bit Intel Mac
- マイク権限と音声認識権限
- 他アプリへ自動入力する場合はアクセシビリティ権限

## 使い方

1. `HSVoice-Installer-1.2.0.pkg`をダブルクリックし、Apple Installerの「続ける」→「インストール」を押します。
2. 初回起動時に「セットアップを開始」を1回押し、表示されるmacOSの確認でマイク、音声認識、アクセシビリティを許可します。権限が揃うとガイドは自動で閉じます。
3. テキスト欄へカーソルを置きます。
4. `fn`（地球儀）キーを押しながら話し、離します。
5. 認識結果がカーソル位置へ入力されます。

メニューバーを開くと、設定画面へ移動せずに認識言語と入力方法を変更できます。直前のテキストは「もう一度入力」または「コピー」で再利用できます。

アクセシビリティが許可されていない場合でも、結果はクリップボードへコピーされます。

初期値は日本語、`fn`キー、押している間だけ録音、自動入力、履歴オフです。利用者が言語やショートカットを選んでから使い始める必要はありません。`fn`キーがない外付けキーボードでは、設定からSpace系ショートカットへ変更できます。macOSのプライバシー確認だけはAppleの仕様上省略できません。

## 利用マニュアル

社内配布・利用者案内には次のファイルを使用してください。

- [編集用Word版](output/documents/HSVoice-1.2.0-User-Manual.docx)
- [配布用PDF版](output/pdf/HSVoice-1.2.0-User-Manual.pdf)

マニュアルには、インストール、初回権限設定、基本操作、メニューバー、ショートカット、言語と辞書、履歴とプライバシー、トラブル対応、社内ITへの問い合わせ方法、クイックリファレンスを収録しています。

## 開発ビルドとテスト

```bash
xcrun swift build
xcrun swift test
```

SwiftPMの実行ファイルを直接起動すると、アプリバンドルの権限説明が使われません。実機で音声認識を確認する場合は、次のリリーススクリプトで生成した`.app`を使用してください。

Codexなど、外側ですでにサンドボックス化された環境ではSwiftPMのネストしたサンドボックスが許可されないことがあります。その場合は`xcrun swift test --disable-sandbox`を使用してください。リリーススクリプトはこの環境にも対応しています。

## 1ファイルのインストーラを作成

社内で利用者へ渡すファイルを1つだけにする場合は、次を実行します。

```bash
./scripts/build-installer.sh
./scripts/verify-installer.sh
```

完成物は[HSVoice-Installer-1.2.0.pkg](release/HSVoice-1.2.0/HSVoice-Installer-1.2.0.pkg)です。このフォルダには配布用PKGが1つだけ生成されます。利用者がPKGをダブルクリックすると、macOS標準のApple Installerが日本語の案内を表示し、確認後に`/Applications/HS Voice.app`をインストールします。コンポーネントは移動不可に設定され、開発用コピーなど別の場所へ移動して更新されることはありません。

macOSの安全機構により、「続ける」「インストール」とTouch IDまたは管理者パスワードの確認は省略できません。

## 開発者向け補助ビルド

以下はアプリ本体・コンポーネントPKG・DMGを個別検証するための開発用手順です。利用者へ渡す完成物には使用せず、配布には上記の単一`HSVoice-Installer-1.2.0.pkg`だけを使用してください。

```bash
./scripts/build-release.sh
./scripts/verify-release.sh
```

ディスクイメージ装置を利用できないCI環境では`SKIP_DMG=1 ./scripts/build-release.sh`でAPP/PKGまで生成し、DMGのみ署名可能なmacOSリリース環境で作成できます。公証時は`SKIP_DMG`を使用しません。

出力先は`dist/`です。

- `HS Voice.app`
- `HSVoice-1.2.0-universal.pkg`
- `HSVoice-1.2.0-universal.dmg`

署名証明書を指定しない場合、アプリはローカル検証用のad-hoc署名、インストーラは未署名です。この出力は機能確認用であり、全社員へ配布する最終版には使用しないでください。

## 会社向けの署名・公証済みビルド

最終配布には会社のApple Developerアカウントに紐づくDeveloper ID証明書が必要です。秘密鍵やApp用パスワードはリポジトリへ保存しません。

```bash
APP_SIGNING_IDENTITY="Developer ID Application: Example Corp (TEAMID1234)" \
INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Example Corp (TEAMID1234)" \
NOTARY_PROFILE="hsvoice-notary" \
BUNDLE_IDENTIFIER="com.example.hsvoice" \
VERSION="1.2.0" \
BUILD_NUMBER="9" \
./scripts/build-installer.sh
```

`NOTARY_PROFILE`は事前にKeychainへ登録します。

```bash
xcrun notarytool store-credentials hsvoice-notary \
  --apple-id "release@example.com" \
  --team-id "TEAMID1234" \
  --password "APP-SPECIFIC-PASSWORD"
```

単体インストーラのビルドスクリプトは、アプリへHardened Runtime署名を行い、最終PKGをDeveloper ID Installerで署名・公証してチケットをstapleします。APP／PKG／DMGの3形式が必要な場合は従来の`build-release.sh`を使用します。

社内展開の詳細は[docs/ENTERPRISE_DEPLOYMENT.md](docs/ENTERPRISE_DEPLOYMENT.md)を参照してください。

MDM管理下のmacOS 14〜26では、最終署名済みアプリからSpeech Recognition、Accessibility、PostEvent用のPPPCプロファイルを生成できます。マイクは従来のPPPCでは事前許可できないため、利用者がmacOSの確認を1回許可します。

```bash
python3 scripts/generate-pppc-profile.py \
  --app "dist/HS Voice.app" \
  --organization "Example Corp" \
  --output "output/mdm/HSVoice-PPPC.mobileconfig"
```

ad-hoc署名ではCode Requirementがビルドごとに変わるため、本番プロファイルの生成は自動的に拒否されます。必ず会社のDeveloper ID Application署名を使ってください。

## プライバシー

- HS Voice自体が運用するサーバーはありません。
- 音声ファイルは保存しません。
- テキスト履歴は初期設定で無効です。
- オンデバイス認識が利用可能な言語では、設定に従ってオンデバイス処理を要求します。
- Apple Speechは、言語・端末・macOSの状態によってAppleのサービスへ接続する場合があります。完全なオフライン動作を保証する設計ではありません。

## 現時点の範囲

HS Voice 1.2は、Aqua Voiceの独自クラウドモデルや高度な生成AIによる言い換え、画面コンテキスト理解、組織SSO、集中管理コンソールを含みません。会社が自らビルド・署名・配布できる安全なネイティブ音声入力基盤です。
