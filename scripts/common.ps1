[CmdletBinding()]
param()

function Get-PolicyPaths {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $codexDirectory = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        Join-Path $HOME '.codex'
    } else {
        $env:CODEX_HOME
    }
    # Reject relative and drive-relative paths: their destination changes with CWD.
    if ($codexDirectory -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+)') {
        throw 'CODEX_HOME must be an absolute Windows path (for example C:\Users\you\.codex).'
    }
    $codexDirectory = [IO.Path]::GetFullPath($codexDirectory)
    $target = Join-Path $codexDirectory 'AGENTS.md'
    # Do not follow junctions/symlinks when installing a global policy.
    $cursor = $target
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing a linked destination: $cursor"
            }
        }
        $parent = Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
    if ((Test-Path -LiteralPath $codexDirectory) -and -not (Test-Path -LiteralPath $codexDirectory -PathType Container)) {
        throw "CODEX_HOME is not a directory: $codexDirectory"
    }
    if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "AGENTS.md is not a file: $target"
    }
    [pscustomobject]@{
        Source = Join-Path $repoRoot 'policy\AGENTS.md'
        Home = $codexDirectory
        Target = $target
    }
}

function Get-PolicyHash([string]$LiteralPath) {
    # Read-only .NET hashing also works during a PS5.1 WhatIf preview.
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($LiteralPath)
    try {
        [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '')
    } finally {
        $stream.Dispose()
        $algorithm.Dispose()
    }
}
