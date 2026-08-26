# HS Voice for Windows 社内展開ガイド

macOS版の社内展開ガイド(hsvoice/docs/ENTERPRISE_DEPLOYMENT.md)のWindows対応版。全社配布では、Authenticode署名済みの単一MSIを配布する。手動配布とIntune/MDM配布で同じMSIを使用できる。

## リリース前に会社側で用意するもの

1. Authenticodeコード署名証明書(OVまたはEV)と秘密鍵。EVはSmartScreenの評判が最初から付くため全社配布に向く。OVはダウンロード実績が溜まるまで警告が出ることがある
2. 署名用マシンの証明書ストアへのインストール(サムプリントを控える)
3. タイムスタンプサーバーへの到達性(既定: timestamp.digicert.com)
4. 対象PCの確認: Windows 10 22H2以降 / Windows 11、x64(AVX2対応CPU)またはARM64、メモリ8GB以上
5. モデル同梱の方針決定(推奨: 同梱。MSIが約+574MBになる代わりに、利用者のダウンロード作業と社内プロキシ問題が消える)

証明書と秘密鍵はGitや配布パッケージへ含めないこと。

## ビルド

ビルドマシン(Windows)で1回だけ:

```powershell
dotnet tool install --global wix
.\scripts\download-model.ps1
```

リリースごと:

```powershell
$env:SIGNING_CERT_THUMBPRINT = "<証明書のサムプリント>"
.\scripts\build-installer.ps1 -BundleModel -Version 1.0.0
.\scripts\verify-installer.ps1 -Version 1.0.0
```

完成物は `release\HSVoice-1.0.0\HSVoice-Installer-1.0.0-x64.msi`。ARM64機(Surface Pro X等)が対象にある場合は `-Arch arm64` でもう1本ビルドする。

クリーンなテスト用PCで、インストール、初回セットアップ、主要業務アプリ(Word・Outlook・ブラウザ・Teams)への入力、サインイン時起動、アンインストールを確認すること。

## 手動インストール

1. 利用者へ署名済みMSIを1ファイルだけ配布する
2. ダブルクリックでWindows Installerが開き、確認後 `C:\Program Files\HS Voice` へインストールされる(管理者権限の確認あり)
3. スタートメニューから HS Voice を起動する
4. 初回セットアップ画面が開く。モデル同梱版ではダウンロード手順は自動的にスキップされ、「使い始める」を押すだけで完了する
5. マイクの確認: Windowsの「設定 → プライバシーとセキュリティ → マイク」で「デスクトップアプリがマイクにアクセスできるようにする」がオンであること

macOSと違い、アクセシビリティ権限・音声認識権限に相当する確認はない。

## Intune(MDM)配布

1. 署名済みMSIを「基幹業務アプリ(LOB)」としてIntuneへ登録する(MSIはWin32ラッピング不要でそのまま配布できる)
2. 必須アプリとして対象グループへ割り当てる
3. マイクのプライバシー設定を組織ポリシーで制御している場合は、`LetAppsAccessMicrophone` がデスクトップアプリを許可していることを確認する
4. 段階展開(IT部門 → パイロット部門 → 全社)を行う

## ウイルス対策ソフトへの対応

HS Voiceはグローバルキーボードフック(ホットキー検出用)と合成キー入力(テキスト挿入用)を使うため、EDR/ウイルス対策製品によっては要確認としてフラグされることがある。展開前に:

1. 署名済みビルドを社内のAVコンソールで許可リストへ登録する(発行元証明書での許可が保守しやすい)
2. 誤検知が続く場合はAVベンダーへ誤検知報告を行う

## アンインストールとデータ

「設定 → アプリ」から標準の手順でアンインストールできる。利用者ごとの設定・履歴・ダウンロードしたモデルは `%APPDATA%\HS Voice` に残る(入力本文を含み得るのは履歴のみで、既定では無効)。完全に消す場合はこのフォルダを削除する。

## 更新

新バージョンは同じUpgradeCodeを持つため、新しいMSIを配布・割当するだけで自動的に置き換わる(ダウングレードは拒否される)。
