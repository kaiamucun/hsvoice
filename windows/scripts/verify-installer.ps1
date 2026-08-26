# HS Voice for Windows — インストーラの検証(macOS版 verify-installer.sh の対応物)
#
# 使い方: .\scripts\verify-installer.ps1 -Version 1.0.0 -Arch x64

param(
    [string]$Version = "1.0.0",
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$msi = Join-Path $root "release\HSVoice-$Version\HSVoice-Installer-$Version-$Arch.msi"

if (-not (Test-Path $msi)) { throw "MSIが見つかりません: $msi" }

$item = Get-Item $msi
Write-Host ("ファイル: {0} ({1:N1} MB)" -f $item.Name, ($item.Length / 1MB))

# 署名の確認
$signature = Get-AuthenticodeSignature $msi
Write-Host "署名状態: $($signature.Status)"
if ($signature.Status -ne "Valid") {
    Write-Warning "MSIが署名されていないか、署名が無効です。全社配布には署名済みMSIを使用してください。"
}

# MSIのプロパティ確認(ProductVersion)
$installer = New-Object -ComObject WindowsInstaller.Installer
$database = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($msi, 0))
$view = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database,
    @("SELECT Value FROM Property WHERE Property = 'ProductVersion'"))
$view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
$record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
$productVersion = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)
Write-Host "ProductVersion: $productVersion"
if ($productVersion -ne $Version) { throw "バージョン不一致: 期待 $Version / 実際 $productVersion" }

Write-Host ""
Write-Host "OK。クリーンなWindows 10/11実機で、インストール → 初回セットアップ → 主要業務アプリへの入力 → アンインストール を確認してください。"
