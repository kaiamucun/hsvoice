# HS Voice 社内展開ガイド

## 推奨配布方式

全社配布では、Developer ID Applicationで署名したアプリを、Developer ID Installerで署名・Appleで公証した単体PKGとして配布してください。手動配布とMDM配布で同じPKGを使用できます。

## リリース前に会社側で用意するもの

1. Apple Developer ProgramまたはApple Developer Enterprise Programのチーム
2. `Developer ID Application`証明書と秘密鍵
3. `Developer ID Installer`証明書と秘密鍵
4. 公証用のApp Store Connect認証情報を登録したKeychain profile
5. 会社所有のBundle ID（例: `com.example.hsvoice`）
6. 対象macOSバージョンとIntel Mac残存台数の確認

証明書、秘密鍵、App用パスワードはGitや配布パッケージへ含めないでください。

## ビルド

プロジェクトルートで次を実行します。

```bash
APP_SIGNING_IDENTITY="Developer ID Application: Example Corp (TEAMID1234)" \
INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Example Corp (TEAMID1234)" \
NOTARY_PROFILE="hsvoice-notary" \
BUNDLE_IDENTIFIER="com.example.hsvoice" \
VERSION="1.2.0" \
BUILD_NUMBER="9" \
./scripts/build-installer.sh
```

次に検証します。

```bash
VERSION="1.2.0" ./scripts/verify-installer.sh
spctl --assess --type execute --verbose=4 "dist/HS Voice.app"
spctl --assess --type install --verbose=4 "release/HSVoice-1.2.0/HSVoice-Installer-1.2.0.pkg"
xcrun stapler validate "release/HSVoice-1.2.0/HSVoice-Installer-1.2.0.pkg"
```

クリーンなテスト用Macで、インストール、初回権限、ログイン起動、主要業務アプリへの入力、アンインストールを確認してください。

## 手動インストール

1. 利用者へ`HSVoice-Installer-<version>.pkg`を1ファイルだけ配布します。
2. 利用者がPKGをダブルクリックするとApple Installerが開きます。
3. 「続ける」→「インストール」を押し、Touch IDまたは管理者パスワードで承認します。
4. 完了後、Finderの「アプリケーション」からHS Voiceを開きます。
5. 初回ガイドで「セットアップを開始」を1回押し、macOSの確認に応答します。必要な権限が揃うとガイドは自動で閉じます。

コンポーネントは移動不可として構成されます。既存の同一Bundle IDが別フォルダにあっても、`/Applications/HS Voice.app`をインストールまたは更新します。

未署名のローカル検証版は全社配布に使用しないでください。会社向けのDeveloper ID署名・公証済みPKGを配布します。

## MDM配布

1. 署名・公証済み`HSVoice-Installer-<version>.pkg`をMDMへ登録します。
2. `/Applications/HS Voice.app`へ必須インストールとして割り当てます。
3. 最終署名済みアプリからPPPC構成プロファイルを生成し、PKGより先に割り当てます。
4. 段階展開（IT部門 → パイロット部門 → 全社）を行います。
5. MDMのインストール結果とクラッシュログを監視します。

## 「設定なし」で使える範囲

利用者がHS Voice内で言語、ショートカット、録音方法、履歴の有無を選ぶ必要はありません。初期値は日本語、`fn`キー、押している間だけ録音、自動入力、履歴オフです。`fn`キーの全アプリ監視にはAccessibilityが使われるため、PPPCをPKGより先に配布してください。

| 配布方法 | 利用者に残る操作 | IT側の準備 |
|---|---|---|
| 署名・公証済みPKGを手動配布 | PKGのインストール承認と、初回のmacOS権限確認 | Developer ID署名、公証、staple |
| MDM（macOS 14〜26） | 原則として初回のマイク許可のみ | 署名・公証済みPKGとPPPCを先行配布 |
| MDM（macOS 27以降） | Appleの組織向け権限同意画面 | Declarative App Settingsを対象OSとMDMで検証 |

Appleのプライバシー保護を無効化して完全な無確認にする設計ではありません。「設定なし」とは、HS Voice独自の設定入力を不要にし、Appleが要求する確認だけに絞ることを意味します。

## PPPC/TCCの考え方

HS Voiceは次のmacOSプライバシー権限を使用します。

| サービス | 目的 | 推奨運用 |
|---|---|---|
| Microphone | 音声入力 | 従来のPPPCでは許可不可。利用者本人が許可する |
| Speech Recognition | 音声からテキストへの変換 | macOS 14〜26ではPPPCで事前許可する |
| Accessibility | 他アプリへの貼り付け操作 | macOS 14〜26ではPPPCで事前許可する |
| Post Event | `Command + V`の貼り付け操作 | macOS 14〜26ではPPPCで事前許可する |

Accessibilityを許可しない部門では、設定の入力方法を「クリップボードへコピーのみ」に固定して運用できます。この場合もマイクと音声認識の権限は必要ですが、HS Voiceは合成キー入力を行いません。

PPPCプロファイルは、最終署名済みアプリから生成してください。

```bash
python3 scripts/generate-pppc-profile.py \
  --app "dist/HS Voice.app" \
  --organization "Example Corp" \
  --output "output/mdm/HSVoice-PPPC.mobileconfig"
```

生成物にはSpeech Recognition、Accessibility、PostEventだけが含まれ、Microphoneは意図的に含まれません。スクリプトはad-hoc/CDHashだけの不安定な署名を本番用として受け付けません。構造確認だけを行う場合に限り`--allow-adhoc`を使用できます。

Bundle IDやTeam IDを変更した場合、古いPPPCプロファイルは一致しません。Jamf Pro、Kandji、Microsoft Intune等へ生成したプロファイルを登録し、必ず最終アプリと同じBundle IDとDesignated Requirementであることを確認してください。

従来のPPPCによるAccessibility事前許可はmacOS 26.2で非推奨となり、macOS 27で廃止予定です。macOS 27以降はAppleのDeclarative App Settingsによる組織向け同意フローへ移行し、対象OSと利用中MDMで実地確認してください。どの方式でもマイクの利用には本人または組織向けのApple同意画面が残ります。

## 更新

- Bundle IDは全バージョンで固定します。
- `CFBundleVersion`はリリースごとに増加させます。
- MDMでは新しい署名済みPKGを同じインストール先へ上書き配布します。
- アプリ更新後に署名要件が同一なら、通常はAccessibility許可を継続できます。証明書またはBundle ID変更時は再評価します。

## ログとデータ

- HS Voiceは音声ファイルを保存しません。
- 履歴はユーザーが有効にした場合のみ、`~/Library/Application Support/HS Voice/history.json`に保存します。
- 設定と辞書は当該ユーザーの`UserDefaults`に保存します。
- アプリ独自の分析SDK、広告SDK、クラッシュ送信SDKは含みません。
- 設定画面の「診断情報をコピー」は、OS・アーキテクチャ・権限・言語・ショートカット・認識方式のみを含みます。音声、入力本文、辞書内容、ユーザー名、端末名は含みません。

## アンインストール

アプリ本体はMDMの削除ポリシー、または`/Applications/HS Voice.app`の削除で除去します。ユーザーごとの履歴と設定は意図せず消さないため自動削除しません。データ消去が必要な場合は、会社のデータ保持ポリシーに従い、対象ユーザーの次の場所を管理対象として削除してください。

- `~/Library/Application Support/HS Voice/`
- Bundle IDに対応する`~/Library/Preferences/<bundle-id>.plist`
