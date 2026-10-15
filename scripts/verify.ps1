[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'policy\AGENTS.md'
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$target = Join-Path $codexHome 'AGENTS.md'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { Write-Error "配布元がありません: $source"; exit 2 }
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { Write-Error "未導入: $target"; exit 1 }
$a = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$b = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if ($a -ne $b) { Write-Warning "ローカル版と配布元に差分があります: $target"; exit 1 }
Write-Host "OK: 共通AGENTS.mdが一致します ($target)"
Write-Host '注: モデル・推論強度の実適用値や、サブエージェントの利用可否は別途Codex内で検証してください。'
