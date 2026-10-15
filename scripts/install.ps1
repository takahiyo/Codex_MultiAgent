[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'common.ps1')
    $paths = Get-PolicyPaths
    $source = $paths.Source
    $target = $paths.Target
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Policy not found: $source" }
    $sourceHash = (Get-PolicyHash $source)
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        if ($sourceHash -eq (Get-PolicyHash $target)) {
            Write-Host "Already up to date: $target"
            exit 0
        }
        if (-not $Force) {
            Write-Warning "Existing AGENTS.md was preserved: $target"
            Write-Host "Compare with: $source"
            Write-Host 'Review differences, then use -Force only if replacement is intended.'
            exit 2
        }
    }
    if ($PSCmdlet.ShouldProcess($target, 'Back up and install shared AGENTS.md')) {
        New-Item -ItemType Directory -Force -Path $paths.Home | Out-Null
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $backupDir = Join-Path $paths.Home ('backups\multiagent-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fffffff') + '-' + [guid]::NewGuid().ToString('N'))
            # Also validate the backup parent before copying anything.
            $backupParent = Join-Path $paths.Home 'backups'
            if ((Test-Path -LiteralPath $backupParent) -and ((Get-Item -LiteralPath $backupParent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "Refusing a linked backup directory: $backupParent"
            }
            New-Item -ItemType Directory -Path $backupDir | Out-Null
            $backup = Join-Path $backupDir 'AGENTS.md'
            $oldHash = (Get-PolicyHash $target)
            Copy-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
            if ((Get-PolicyHash $backup) -ne $oldHash) { throw 'Backup verification failed; installation stopped.' }
            Write-Host "Backup: $backupDir"
        }
        # Replace the directory entry, never overwrite an existing hard-linked file.
        $staged = Join-Path $paths.Home ('.multiagent-' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::WriteAllBytes($staged, [IO.File]::ReadAllBytes($source))
            if ((Get-PolicyHash $staged) -ne $sourceHash) { throw 'Staged policy hash does not match source.' }
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                [IO.File]::Replace($staged, $target, [NullString]::Value)
            } else {
                [IO.File]::Move($staged, $target)
            }
        } finally {
            if (Test-Path -LiteralPath $staged -PathType Leaf) { Remove-Item -LiteralPath $staged -ErrorAction Stop }
        }
        if ((Get-PolicyHash $target) -ne $sourceHash) { throw 'Installed policy hash does not match source.' }
        Write-Host "Installed: $target"
        Write-Host 'config.toml and credentials were not modified. Start a new Codex session to test.'
    }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
