# HS Voice for Windows — 配布用MSIインストーラのビルド
#
# macOS版 build-installer.sh の対応物。1ファイルのMSIを release\ へ生成する。
#
# 前提(1回だけ):
#   - .NET 8 SDK
#   - WiXツールセット: dotnet tool install --global wix
#
# 使い方:
#   .\scripts\build-installer.ps1                       # x64・モデル同梱なし
#   .\scripts\build-installer.ps1 -BundleModel          # models\*.bin を同梱(推奨・約+574MB)
#   .\scripts\build-installer.ps1 -Arch arm64           # Windows on ARM向け
#
# 署名(全社配布では必須 — 未署名はSmartScreenで警告される):
#   $env:SIGNING_CERT_THUMBPRINT = "証明書のサムプリント"
#   を設定してから実行すると、EXEとMSIの両方にsigntoolで署名する。

param(
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64",
    [switch]$BundleModel,
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$publishDir = Join-Path $root "dist\publish-$Arch"
$releaseDir = Join-Path $root "release\HSVoice-$Version"

Write-Host "== 1/4 publish (self-contained, win-$Arch) =="
dotnet publish (Join-Path $root "src\HSVoice.App") `
    -c Release -r "win-$Arch" --self-contained `
    -p:Version=$Version `
    -o $publishDir

if ($BundleModel) {
    Write-Host "== モデルを同梱 =="
    $models = Get-ChildItem (Join-Path $root "models") -Filter "ggml-*.bin" -ErrorAction SilentlyContinue
    if (-not $models) {
        throw "models\ にモデルがありません。先に .\scripts\download-model.ps1 を実行してください。"
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $publishDir "models") | Out-Null
    $models | Copy-Item -Destination (Join-Path $publishDir "models") -Force
}

if ($env:SIGNING_CERT_THUMBPRINT) {
    Write-Host "== 2/4 実行ファイルへ署名 =="
    & signtool sign /sha1 $env:SIGNING_CERT_THUMBPRINT /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
        (Join-Path $publishDir "HSVoice.exe")
} else {
    Write-Host "== 2/4 署名スキップ(SIGNING_CERT_THUMBPRINT未設定 — ローカル検証用) =="
}

Write-Host "== 3/4 MSIビルド =="
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
$msi = Join-Path $releaseDir "HSVoice-Installer-$Version-$Arch.msi"
wix build (Join-Path $root "Packaging\Package.wxs") `
    -arch $Arch `
    -d "ProductVersion=$Version" `
    -d "PublishDir=$publishDir" `
    -o $msi

if ($env:SIGNING_CERT_THUMBPRINT) {
    Write-Host "== 4/4 MSIへ署名 =="
    & signtool sign /sha1 $env:SIGNING_CERT_THUMBPRINT /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $msi
} else {
    Write-Host "== 4/4 MSI署名スキップ =="
}

Write-Host ""
Write-Host "完成: $msi"
Write-Host "検証: .\scripts\verify-installer.ps1 -Version $Version -Arch $Arch"
