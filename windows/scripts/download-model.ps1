# HS Voice for Windows — whisperモデルのダウンロード
#
# 使い方(PowerShellで):
#   .\scripts\download-model.ps1                # 推奨モデル(large-v3-turbo量子化版・約574MB)
#   .\scripts\download-model.ps1 -Model small   # 低スペックPC向け(約466MB)
#
# 保存先: リポジトリ直下の models\ フォルダ。
# アプリはこのフォルダ(実行ファイルの隣のmodels\)または
# %APPDATA%\HS Voice\models\ から自動でモデルを検出します。

param(
    [ValidateSet("large-v3-turbo", "small", "medium")]
    [string]$Model = "large-v3-turbo"
)

$ErrorActionPreference = "Stop"

$files = @{
    "large-v3-turbo" = "ggml-large-v3-turbo-q5_0.bin"
    "small"          = "ggml-small.bin"
    "medium"         = "ggml-medium-q5_0.bin"
}

$fileName = $files[$Model]
$url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fileName"
$destinationDirectory = Join-Path $PSScriptRoot "..\models"
New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
$destination = Join-Path $destinationDirectory $fileName

if (Test-Path $destination) {
    Write-Host "既にダウンロード済みです: $destination"
    exit 0
}

Write-Host "ダウンロード中: $url"
Write-Host "保存先: $destination"
Write-Host "(数百MBあります。社内プロキシ環境では環境変数 HTTPS_PROXY の設定が必要な場合があります)"

Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing

Write-Host "完了しました。アプリをビルド・実行するとこのモデルが自動検出されます。"
