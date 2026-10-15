[CmdletBinding()]
param()

function Assert-PolicyFile([string]$LiteralPath) {
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { return }
    if ((Get-Item -LiteralPath $LiteralPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing a linked policy file: $LiteralPath"
    }
    if (-not ('CodexMultiAgent.FileMetadata' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using FILETIME = System.Runtime.InteropServices.ComTypes.FILETIME;
using Microsoft.Win32.SafeHandles;
namespace CodexMultiAgent {
    public static class FileMetadata {
        [StructLayout(LayoutKind.Sequential)]
        private struct FileInformation {
            public uint Attributes;
            public FILETIME CreationTime, LastAccessTime, LastWriteTime;
            public uint VolumeSerialNumber, SizeHigh, SizeLow, NumberOfLinks, IndexHigh, IndexLow;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInformation info);
        public static uint LinkCount(string path) {
            using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
                FileInformation info;
                if (!GetFileInformationByHandle(stream.SafeFileHandle, out info))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                return info.NumberOfLinks;
            }
        }
    }
}
"@
    }
    # Query metadata before hashing or backing up: a hard link can alias auth/config.
    if ([CodexMultiAgent.FileMetadata]::LinkCount($LiteralPath) -ne 1) {
        throw "Refusing a hard-linked policy file: $LiteralPath"
    }
}

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
    $source = Join-Path $repoRoot 'policy\AGENTS.md'
    Assert-PolicyFile $source
    Assert-PolicyFile $target
    [pscustomobject]@{
        Source = $source
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
