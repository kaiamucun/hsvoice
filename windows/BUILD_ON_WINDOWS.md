# Windows PCでのMSIビルド手順(社内配布サイト掲載用)

このフォルダをWindows PCへコピーし、PowerShellで以下を実行します。

## 準備(初回のみ)

```powershell
winget install Microsoft.DotNet.SDK.8
dotnet tool install --global wix
```

## ビルド(モデル非同梱・推奨)

```powershell
cd <このフォルダ>
.\scripts\build-installer.ps1
```

→ `release\HSVoice-1.0.0\HSVoice-Installer-1.0.0-x64.msi` ができます(約60〜90MB想定)。
※ モデル非同梱でも、アプリの初回起動時に自動でモデルをダウンロードするため利用者の操作はほぼ不要です。
※ モデル同梱版(約700MB)はGitHubに置けないため、サイト掲載には非同梱版を使ってください。

## サイトへの掲載

1. できたMSIファイルをMacの `Desktop/dev/hsvoice/release-windows/` フォルダにコピー(AirDropなど)
2. Macで `publish-download-site.command` をダブルクリック

これだけでダウンロードサイトにWindows版ボタンが追加されます。
