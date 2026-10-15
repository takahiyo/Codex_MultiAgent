[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'policy\AGENTS.md'
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$target = Join-Path $codexHome 'AGENTS.md'

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Policy not found: $source" }
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
if (Test-Path -LiteralPath $target -PathType Leaf) {
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($sourceHash -eq $targetHash) { Write-Host "Already up to date: $target"; exit 0 }
    if (-not $Force) {
        Write-Warning "Existing AGENTS.md was preserved. Review differences; use -Force only to replace it: $target"
        exit 2
    }
}
if ($PSCmdlet.ShouldProcess($target, 'Back up and install shared AGENTS.md')) {
    New-Item -ItemType Directory -Force -Path $codexHome | Out-Null
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'
        $backupDir = Join-Path $codexHome "backups\multiagent-$stamp"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir 'AGENTS.md') -ErrorAction Stop
        Write-Host "Backup: $backupDir"
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Installed policy hash does not match source.' }
    Write-Host "Installed: $target"
    Write-Host 'config.toml and credentials were not modified. Start a new Codex session to test.'
}
