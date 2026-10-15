[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'policy\AGENTS.md'
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$target = Join-Path $codexHome 'AGENTS.md'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { Write-Error "Policy not found: $source"; exit 2 }
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { Write-Error "Not installed: $target"; exit 1 }
$a = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$b = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if ($a -ne $b) { Write-Warning "Installed policy differs from shared policy: $target"; exit 1 }
Write-Host "OK: Shared AGENTS.md matches ($target)"
Write-Host 'Note: Check delegation availability and effective model/effort separately in Codex.'
