[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'policy\AGENTS.md'
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$target = Join-Path $codexHome 'AGENTS.md'

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "共通ポリシーが見つかりません: $source" }
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
if (Test-Path -LiteralPath $target -PathType Leaf) {
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($sourceHash -eq $targetHash) { Write-Host "設定は最新です: $target"; exit 0 }
    if (-not $Force) {
        Write-Warning "既存のAGENTS.mdを保護しました。差分を確認し、置き換える場合だけ -Force を指定してください: $target"
        exit 2
    }
}
if ($PSCmdlet.ShouldProcess($target, 'バックアップして共通AGENTS.mdを配置')) {
    New-Item -ItemType Directory -Force -Path $codexHome | Out-Null
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'
        $backupDir = Join-Path $codexHome "backups\multiagent-$stamp"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir 'AGENTS.md') -ErrorAction Stop
        Write-Host "バックアップ: $backupDir"
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $sourceHash) { throw '配置後のハッシュが一致しません。' }
    Write-Host "配置完了: $target"
    Write-Host 'config.toml と認証情報は変更していません。Codexの新規セッションで確認してください。'
}
