[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('multiagent-test-' + [guid]::NewGuid().ToString('N'))
$engineName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$engine = Join-Path $PSHOME $engineName
$savedHome = $env:CODEX_HOME
$savedLocation = Get-Location
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Run($name, $expected, [string[]]$options = @()) {
    & $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts\$name.ps1") @options
    Assert ($LASTEXITCODE -eq $expected) "$name expected exit $expected, got $LASTEXITCODE"
}
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Set-Location -LiteralPath $testRoot
    $env:CODEX_HOME = Join-Path $testRoot ('space [ab] home ' + [char]0x65E5 + [char]0x672C)
    Run 'verify' 1
    Run 'install' 0 @('-WhatIf')
    Assert (-not (Test-Path -LiteralPath $env:CODEX_HOME)) 'WhatIf created destination'
    Run 'install' 0
    Run 'verify' 0
    $target = Join-Path $env:CODEX_HOME 'AGENTS.md'
    Run 'install' 0
    Assert (-not (Test-Path -LiteralPath (Join-Path $env:CODEX_HOME 'backups'))) 'Identical install created backup'
    [IO.File]::WriteAllBytes($target, [byte[]]@())
    [IO.File]::WriteAllText((Join-Path $env:CODEX_HOME 'config.toml'), 'test settings')
    [IO.File]::WriteAllText((Join-Path $env:CODEX_HOME 'auth.json'), 'test credentials placeholder')
    $before = @{}
    foreach ($file in @('config.toml', 'auth.json')) { $before[$file] = (Get-FileHash -LiteralPath (Join-Path $env:CODEX_HOME $file)).Hash }
    Run 'install' 2
    Assert ((Get-Item -LiteralPath $target).Length -eq 0) 'Difference protection changed target'
    Run 'verify' 1
    Run 'install' 0 @('-Force', '-WhatIf')
    Assert ((Get-Item -LiteralPath $target).Length -eq 0) 'WhatIf overwrote target'
    Assert (-not (Test-Path -LiteralPath (Join-Path $env:CODEX_HOME 'backups'))) 'WhatIf created backup'
    Run 'install' 0 @('-Force')
    Run 'verify' 0
    $backups = @(Get-ChildItem -LiteralPath (Join-Path $env:CODEX_HOME 'backups') -Recurse -File)
    Assert ($backups.Count -eq 1 -and $backups[0].Length -eq 0) 'Backup did not preserve empty original'
    Run 'install' 0 @('-Force')
    Assert (@(Get-ChildItem -LiteralPath (Join-Path $env:CODEX_HOME 'backups') -Recurse -File).Count -eq 1) 'Identical Force created backup'
    foreach ($file in @('config.toml', 'auth.json')) { Assert ((Get-FileHash -LiteralPath (Join-Path $env:CODEX_HOME $file)).Hash -eq $before[$file]) "Protected file changed: $file" }
    [IO.File]::WriteAllText($target, 'custom original rules')
    $oldHash = (Get-FileHash -LiteralPath $target).Hash
    Run 'install' 2
    Run 'install' 0 @('-Force')
    $copies = @(Get-ChildItem -LiteralPath (Join-Path $env:CODEX_HOME 'backups') -Recurse -File)
    Assert (@($copies | Where-Object { (Get-FileHash -LiteralPath $_.FullName).Hash -eq $oldHash }).Count -eq 1) 'Nonempty backup differs'
    $env:CODEX_HOME = Join-Path $testRoot 'backup failure'
    New-Item -ItemType Directory -Path $env:CODEX_HOME | Out-Null
    $blockedTarget = Join-Path $env:CODEX_HOME 'AGENTS.md'
    [IO.File]::WriteAllText($blockedTarget, 'preserve on backup failure')
    [IO.File]::WriteAllText((Join-Path $env:CODEX_HOME 'backups'), 'block directory creation')
    Run 'install' 1 @('-Force')
    Assert ([IO.File]::ReadAllText($blockedTarget) -eq 'preserve on backup failure') 'Backup failure changed target'
    $env:CODEX_HOME = Join-Path $testRoot 'hardlink home'
    New-Item -ItemType Directory -Path $env:CODEX_HOME | Out-Null
    $protected = Join-Path $env:CODEX_HOME 'config.toml'
    [IO.File]::WriteAllText($protected, 'hardlink protected settings')
    $linkedTarget = Join-Path $env:CODEX_HOME 'AGENTS.md'
    New-Item -ItemType HardLink -Path $linkedTarget -Target $protected | Out-Null
    Run 'install' 1 @('-Force')
    Run 'verify' 1
    Assert ([IO.File]::ReadAllText($protected) -eq 'hardlink protected settings') 'Hardlink overwrite changed config'
    Assert (-not (Test-Path -LiteralPath (Join-Path $env:CODEX_HOME 'backups'))) 'Hardlink contents copied to backup'
    $authHome = Join-Path $testRoot 'auth hardlink home'
    New-Item -ItemType Directory -Path $authHome | Out-Null
    $authFixture = Join-Path $authHome 'auth.json'
    [IO.File]::WriteAllText($authFixture, 'FAKE_AUTH_SENTINEL_FOR_TEST')
    New-Item -ItemType HardLink -Path (Join-Path $authHome 'AGENTS.md') -Target $authFixture | Out-Null
    $env:CODEX_HOME = $authHome
    Run 'install' 1 @('-Force')
    Assert ([IO.File]::ReadAllText($authFixture) -eq 'FAKE_AUTH_SENTINEL_FOR_TEST') 'Hardlink overwrite changed auth'
    Assert (-not (Test-Path -LiteralPath (Join-Path $authHome 'backups'))) 'Auth contents copied to backup'
    $sourceFixture = Join-Path $testRoot 'hardlinked source repo'
    New-Item -ItemType Directory -Path (Join-Path $sourceFixture 'scripts') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $sourceFixture 'policy') | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'scripts') -Filter '*.ps1') {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $sourceFixture 'scripts')
    }
    New-Item -ItemType HardLink -Path (Join-Path $sourceFixture 'policy\AGENTS.md') -Target $authFixture | Out-Null
    $env:CODEX_HOME = Join-Path $testRoot 'source rejected destination'
    & $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sourceFixture 'scripts\install.ps1') -Force
    Assert ($LASTEXITCODE -eq 1) 'Hard-linked source was accepted'
    Assert (-not (Test-Path -LiteralPath $env:CODEX_HOME)) 'Rejected source created destination'
    $env:CODEX_HOME = Join-Path $testRoot 'junction home'
    New-Item -ItemType Junction -Path $env:CODEX_HOME -Target (Join-Path $testRoot 'hardlink home') | Out-Null
    Run 'install' 1 @('-Force')
    foreach ($relative in @('.codex', 'C:relative')) {
        $env:CODEX_HOME = $relative
        Run 'install' 1 @('-Force')
        Run 'verify' 1
    }
    $env:CODEX_HOME = Join-Path $testRoot 'directory target'
    New-Item -ItemType Directory -Path (Join-Path $env:CODEX_HOME 'AGENTS.md') | Out-Null
    Run 'install' 1 @('-Force')
    foreach ($script in @(Get-ChildItem -LiteralPath (Join-Path $repo 'scripts') -Filter '*.ps1') + @(Get-Item -LiteralPath $PSCommandPath)) {
        $bytes = [IO.File]::ReadAllBytes($script.FullName)
        Assert ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) "Missing UTF-8 BOM: $($script.Name)"
        $tokens = $null; $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        Assert ($parseErrors.Count -eq 0) "Parse errors: $($script.Name)"
    }
    Write-Host 'PASS: CWD independence, special paths, install, verify, conflict, WhatIf, Force backup, protected files, links, invalid paths, BOM and parsing.'
    Write-Host "Engine: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Write-Host "Temporary fixtures retained at: $testRoot"
} finally {
    $env:CODEX_HOME = $savedHome
    Set-Location -LiteralPath $savedLocation
}
exit 0
