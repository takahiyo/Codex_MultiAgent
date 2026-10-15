[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'common.ps1')
    $paths = Get-PolicyPaths
    if (-not (Test-Path -LiteralPath $paths.Source -PathType Leaf)) { throw "Policy not found: $($paths.Source)" }
    if (-not (Test-Path -LiteralPath $paths.Target -PathType Leaf)) { throw "Not installed: $($paths.Target)" }
    $a = (Get-FileHash -LiteralPath $paths.Source -Algorithm SHA256).Hash
    $b = (Get-FileHash -LiteralPath $paths.Target -Algorithm SHA256).Hash
    if ($a -ne $b) { throw "Installed policy differs from shared policy: $($paths.Target)" }
    Write-Host "OK: Shared AGENTS.md matches ($($paths.Target))"
    Write-Host 'Note: Check delegation availability and effective model/effort separately in a new Codex session.'
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
