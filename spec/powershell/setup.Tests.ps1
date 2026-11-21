# Pester 5 tests for setup.ps1. Run: Invoke-Pester spec/powershell

BeforeAll {
  # Dot-sourcing loads the functions without running Invoke-Setup.
  . (Join-Path $PSScriptRoot '..\..\setup.ps1')
}

Describe 'Get-ProfileWrapper' {
  It 'dot-sources the repo profile between the local pre and post files' {
    $lines = (Get-ProfileWrapper -DotfilesDir 'C:\dots') -split "`r`n"
    $lines[0] | Should -BeLike "$ManagedFileHeader*"
    $lines[1] | Should -BeLike '*.pwsh_pre.ps1*'
    $lines[2] | Should -Be ". 'C:\dots\powershell\profile.ps1'"
    $lines[3] | Should -BeLike '*.pwsh_post.ps1*'
  }

  It 'escapes single quotes in the repo path' {
    Get-ProfileWrapper -DotfilesDir "C:\it's" | Should -BeLike "*. 'C:\it''s\powershell*"
  }

  It 'is valid PowerShell' {
    $errors = $null
    $null = [Management.Automation.PSParser]::Tokenize(
      (Get-ProfileWrapper -DotfilesDir "C:\it's"), [ref]$errors)
    $errors | Should -BeNullOrEmpty
  }
}

Describe 'Write-ProfileWrapper' {
  BeforeEach {
    $script:profilePath = Join-Path $TestDrive "$([guid]::NewGuid())\profile.ps1"
    $script:expected = Get-ProfileWrapper -DotfilesDir 'C:\dots'
  }

  It 'creates the profile and its folder' {
    Write-ProfileWrapper -ProfilePath $profilePath -DotfilesDir 'C:\dots'
    [IO.File]::ReadAllText($profilePath) | Should -Be $expected
  }

  It 'backs up a profile it did not write' {
    $null = New-Item -ItemType File -Force -Path $profilePath -Value 'Import-Module Foo'
    Write-ProfileWrapper -ProfilePath $profilePath -DotfilesDir 'C:\dots'
    [IO.File]::ReadAllText("$profilePath.bak") | Should -Be 'Import-Module Foo'
    [IO.File]::ReadAllText($profilePath) | Should -Be $expected
  }

  It 'replaces an older generated wrapper without a backup' {
    $old = Get-ProfileWrapper -DotfilesDir 'C:\old'
    $null = New-Item -ItemType File -Force -Path $profilePath -Value $old
    Write-ProfileWrapper -ProfilePath $profilePath -DotfilesDir 'C:\dots'
    Test-Path "$profilePath.bak" | Should -BeFalse
    [IO.File]::ReadAllText($profilePath) | Should -Be $expected
  }

  It 'leaves a current wrapper untouched' {
    Write-ProfileWrapper -ProfilePath $profilePath -DotfilesDir 'C:\dots'
    $past = [datetime]'2000-01-01'
    (Get-Item $profilePath).LastWriteTime = $past
    Write-ProfileWrapper -ProfilePath $profilePath -DotfilesDir 'C:\dots'
    (Get-Item $profilePath).LastWriteTime | Should -Be $past
    Test-Path "$profilePath.bak" | Should -BeFalse
  }
}

Describe 'Get-GhosttyWrapper' {
  It 'includes the shared config, then the Windows config, then config.local' {
    $lines = (Get-GhosttyWrapper -DotfilesDir 'C:\my dots') -split "`r`n"
    $lines[0] | Should -BeLike "$ManagedFileHeader*"
    $lines[1] | Should -Be 'config-file = "C:\my dots\ghostty\config"'
    $lines[2] | Should -Be 'config-file = "C:\my dots\ghostty\windows"'
    $lines[3] | Should -Be 'config-file = ?config.local'
  }

  It 'points at files that exist in the repo' {
    $repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    foreach ($name in 'config', 'windows', 'linux', 'macos', 'keys-alt') {
      Join-Path $repo "ghostty\$name" | Should -Exist
    }
  }
}

Describe 'Get-GhosttyConfigPath' {
  It 'prefers XDG_CONFIG_HOME, like Ghostty does' {
    $saved = $env:XDG_CONFIG_HOME
    try {
      $env:XDG_CONFIG_HOME = 'C:\xdg'
      Get-GhosttyConfigPath | Should -Be 'C:\xdg\ghostty\config.ghostty'
      $env:XDG_CONFIG_HOME = $null
      Get-GhosttyConfigPath | Should -Be "$env:LOCALAPPDATA\ghostty\config.ghostty"
    } finally {
      $env:XDG_CONFIG_HOME = $saved
    }
  }
}

Describe 'Write-GhosttyWrapper' {
  It 'backs up a hand-written Ghostty config and writes the wrapper' {
    $path = Join-Path $TestDrive 'ghostty\config.ghostty'
    $null = New-Item -ItemType File -Force -Path $path -Value 'font-size = 20'
    Write-GhosttyWrapper -ConfigPath $path -DotfilesDir 'C:\dots'
    [IO.File]::ReadAllText("$path.bak") | Should -Be 'font-size = 20'
    [IO.File]::ReadAllText($path) | Should -Be (Get-GhosttyWrapper -DotfilesDir 'C:\dots')
  }
}

Describe 'Write-AutoHotkeyStartup' {
  BeforeAll {
    $script:shell = New-Object -ComObject WScript.Shell
    $script:ahk = 'C:\Program Files\AutoHotkey\v2\AutoHotkey.exe'
  }
  BeforeEach {
    $script:lnk = Join-Path $TestDrive "$([guid]::NewGuid()).lnk"
  }

  It 'creates a shortcut that runs init.ahk with AutoHotkey' {
    Write-AutoHotkeyStartup -ShortcutPath $lnk -AutoHotkey $ahk -Script 'C:\my dots\init.ahk'
    $saved = $shell.CreateShortcut($lnk)
    $saved.TargetPath | Should -Be $ahk
    $saved.Arguments | Should -Be '"C:\my dots\init.ahk"'
    $saved.WorkingDirectory | Should -Be 'C:\my dots'
  }

  It 'repoints a shortcut to an old checkout' {
    $old = $shell.CreateShortcut($lnk)
    $old.TargetPath = 'C:\Code\dotfiles\init.ahk'
    $old.Save()
    Write-AutoHotkeyStartup -ShortcutPath $lnk -AutoHotkey $ahk -Script 'C:\dots\init.ahk' `
      6>$null
    $shell.CreateShortcut($lnk).TargetPath | Should -Be $ahk
  }

  It 'leaves a correct shortcut untouched' {
    Write-AutoHotkeyStartup -ShortcutPath $lnk -AutoHotkey $ahk -Script 'C:\dots\init.ahk'
    $past = [datetime]'2000-01-01'
    (Get-Item $lnk).LastWriteTime = $past
    Write-AutoHotkeyStartup -ShortcutPath $lnk -AutoHotkey $ahk -Script 'C:\dots\init.ahk'
    (Get-Item $lnk).LastWriteTime | Should -Be $past
  }
}

Describe 'Set-AutoHotkeyStartup' {
  BeforeEach {
    Mock Write-AutoHotkeyStartup {}
    Mock Start-AutoHotkey {}
  }

  It 'registers and restarts init.ahk from the repo' {
    Mock Find-AutoHotkey { 'C:\ahk.exe' }
    Set-AutoHotkeyStartup -DotfilesDir 'C:\dots'
    Should -Invoke Write-AutoHotkeyStartup -Times 1 -Exactly -ParameterFilter {
      $AutoHotkey -eq 'C:\ahk.exe' -and $Script -eq 'C:\dots\init.ahk' -and
        $ShortcutPath -like '*\Startup\init.ahk.lnk'
    }
    Should -Invoke Start-AutoHotkey -Times 1 -Exactly
  }

  It 'skips everything when AutoHotkey is missing' {
    Mock Find-AutoHotkey { $null }
    Set-AutoHotkeyStartup -DotfilesDir 'C:\dots' -WarningAction SilentlyContinue
    Should -Invoke Write-AutoHotkeyStartup -Times 0 -Exactly
    Should -Invoke Start-AutoHotkey -Times 0 -Exactly
  }
}

Describe 'Test-DotfilesPackageInstalled' {
  It 'finds a package by command or by path' {
    $byCommand = [pscustomobject]@{ Command = 'powershell'; Paths = @() }
    $byPath = [pscustomobject]@{ Command = $null; Paths = @($PSCommandPath) }
    $missing = [pscustomobject]@{ Command = 'no-such-cmd-xyz'; Paths = @('C:\no\such.exe') }
    Test-DotfilesPackageInstalled -Package $byCommand | Should -BeTrue
    Test-DotfilesPackageInstalled -Package $byPath | Should -BeTrue
    Test-DotfilesPackageInstalled -Package $missing | Should -BeFalse
  }
}

Describe 'Set-GitInclude' {
  BeforeEach {
    # Point git's global config at a scratch file instead of ~/.gitconfig.
    $script:savedGlobal = $env:GIT_CONFIG_GLOBAL
    $env:GIT_CONFIG_GLOBAL = Join-Path $TestDrive "$([guid]::NewGuid()).gitconfig"
  }
  AfterEach {
    $env:GIT_CONFIG_GLOBAL = $savedGlobal
  }

  It 'adds the repo .gitconfig once, keeping other includes' {
    & git config --global include.path 'C:/other.gitconfig'
    Set-GitInclude -DotfilesDir 'C:\dots'
    Set-GitInclude -DotfilesDir 'C:\dots'
    $includes = @(& git config --global --get-all include.path)
    $includes | Should -Be @('C:/other.gitconfig', 'C:/dots/.gitconfig')
  }
}

Describe 'repo .gitconfig' {
  It 'loads in Git for Windows, which setup.sh includes it into' {
    $gitconfig = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.gitconfig')).Path
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    # Integer settings are only checked when git reads them, so run a real command.
    $out = & git -c "include.path=$gitconfig" -C $repo status --short 2>&1
    $LASTEXITCODE | Should -Be 0 -Because "$out"
  }
}

Describe 'repo PowerShell files' {
  It 'are ASCII so Windows PowerShell 5.1 reads them correctly' {
    $root = Join-Path $PSScriptRoot '..\..'
    $files = @(Get-ChildItem (Join-Path $root 'powershell') -Filter '*.ps*') +
      @(Get-Item (Join-Path $root 'setup.ps1'), (Join-Path $root 'install.ps1'))
    foreach ($file in $files) {
      $bytes = [IO.File]::ReadAllBytes($file.FullName)
      @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0 -Because $file.Name
    }
  }

  It 'parse without errors' {
    $root = Join-Path $PSScriptRoot '..\..'
    $files = @(Get-ChildItem (Join-Path $root 'powershell') -Filter '*.ps1') +
      @(Get-Item (Join-Path $root 'setup.ps1'), (Join-Path $root 'install.ps1'))
    foreach ($file in $files) {
      $errors = $null
      $null = [Management.Automation.PSParser]::Tokenize(
        [IO.File]::ReadAllText($file.FullName), [ref]$errors)
      $errors | Should -BeNullOrEmpty -Because $file.Name
    }
  }

  It 'include a theme that oh-my-posh accepts' -Skip:(-not (Get-Command oh-my-posh -EA 0)) {
    $theme = Join-Path $PSScriptRoot '..\..\powershell\p10k.omp.json'
    # Inside an oh-my-posh shell, the session's POSH_* variables override --config.
    $saved = Get-ChildItem env: | Where-Object Name -like 'POSH_*'
    $saved | ForEach-Object { Remove-Item "env:$($_.Name)" }
    try {
      $out = & oh-my-posh print primary --config $theme --shell pwsh --plain 2>&1
    } finally {
      $saved | ForEach-Object { Set-Item "env:$($_.Name)" $_.Value }
    }
    $LASTEXITCODE | Should -Be 0
    "$out" | Should -Match '\u276f'
  }
}
