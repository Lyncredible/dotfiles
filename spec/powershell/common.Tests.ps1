# Pester 5 tests for powershell/common.ps1. Run: Invoke-Pester spec/powershell

BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\powershell\common.ps1')
}

Describe 'Get-DotfilesStringIndex' {
  # Values from .local/bin/whereami's string_to_index "<string>" 75.
  It 'hashes <String> to <Index> like the sh script' -ForEach @(
    @{ String = 'Lephyrus'; Index = 18 }
    @{ String = 'LEPHYRUS'; Index = 20 }
    @{ String = 'test-host'; Index = 23 }
    @{ String = 'a'; Index = 22 }
  ) {
    Get-DotfilesStringIndex -String $String -Modulo 75 | Should -Be $Index
  }
}

Describe 'Get-DotfilesWhereami' {
  BeforeAll {
    $script:hostName = ([Net.Dns]::GetHostName() -split '\.')[0]
    $script:repoScript = Join-Path $PSScriptRoot '..\..\.local\bin\whereami'
  }

  It "names the machine with the emoji the sh script would pick" {
    $emojis = (Select-String -LiteralPath $repoScript -Pattern '^\s*emojis="(.*)"' -Encoding utf8
      ).Matches[0].Groups[1].Value -split ' '
    $expected = $emojis[(Get-DotfilesStringIndex -String $hostName -Modulo 75)]
    Get-DotfilesWhereami -Script $repoScript | Should -BeExactly "$hostName $expected"
  }

  It 'reads the emoji list from the script' {
    $fake = Join-Path $TestDrive 'whereami'
    $list = (1..75 | ForEach-Object { "e$_" }) -join ' '
    Set-Content -LiteralPath $fake -Value "    emojis=`"$list`""
    $index = Get-DotfilesStringIndex -String $hostName -Modulo 75
    Get-DotfilesWhereami -Script $fake | Should -BeExactly "$hostName e$($index + 1)"
  }

  It 'is the bare name when the script is missing' {
    Get-DotfilesWhereami -Script (Join-Path $TestDrive 'missing') | Should -BeExactly $hostName
  }

  It 'uses whereami-resolve when it is on PATH' {
    $bin = Join-Path $TestDrive 'bin'
    $null = New-Item -ItemType Directory -Force -Path $bin
    Set-Content -LiteralPath (Join-Path $bin 'whereami-resolve.cmd') -Value @(
      '@echo off'
      'if "%1"=="--emoji" (echo X) else (echo work-laptop)'
    )
    $savedPath = $env:Path
    try {
      $env:Path = "$bin;$env:Path"
      Get-DotfilesWhereami -Script $repoScript | Should -BeExactly 'work-laptop X'
    } finally {
      $env:Path = $savedPath
    }
  }
}

Describe 'Get-DotfilesMissingTools' {
  BeforeEach {
    $script:noUv = $env:NO_UV
    Remove-Item Env:NO_UV -ErrorAction SilentlyContinue
  }
  AfterEach { $env:NO_UV = $noUv }

  It 'lists uv and fzf when they are not on PATH' {
    Mock Get-Command { $null }
    Get-DotfilesMissingTools | Should -Be @('uv', 'fzf')
  }

  It 'skips uv when NO_UV is true, like main.zshrc' {
    Mock Get-Command { $null }
    $env:NO_UV = 'true'
    Get-DotfilesMissingTools | Should -Be @('fzf')
  }

  It 'is empty when both are installed' {
    Mock Get-Command { [pscustomobject]@{ Name = $Name } }
    Get-DotfilesMissingTools | Should -BeNullOrEmpty
  }
}

Describe 'Get-DotfilesEditor' {
  BeforeEach {
    $script:ssh = $env:SSH_CONNECTION
    Remove-Item Env:SSH_CONNECTION -ErrorAction SilentlyContinue
  }
  AfterEach { $env:SSH_CONNECTION = $ssh }

  It 'is vim over SSH' {
    $env:SSH_CONNECTION = '10.0.0.1 22 10.0.0.2 22'
    Get-DotfilesEditor | Should -Be 'vim'
  }

  It 'is subl when it is on PATH' {
    Mock Get-Command { [pscustomobject]@{ Name = 'subl' } } -ParameterFilter { $Name -eq 'subl' }
    Get-DotfilesEditor -SublimePaths @() | Should -Be 'subl -n -w'
  }

  It 'quotes the install path when subl is not on PATH' {
    Mock Get-Command { $null } -ParameterFilter { $Name -eq 'subl' }
    $subl = Join-Path $TestDrive 'Sublime Text\subl.exe'
    $null = New-Item -ItemType File -Force -Path $subl
    Get-DotfilesEditor -SublimePaths @('C:\no\subl.exe', $subl) |
      Should -Be "`"$subl`" -n -w"
  }

  It 'is null without Sublime Text' {
    Mock Get-Command { $null } -ParameterFilter { $Name -eq 'subl' }
    Get-DotfilesEditor -SublimePaths @('C:\no\subl.exe') | Should -BeNullOrEmpty
  }
}

Describe 'Read-DotfilesUpdateTimestamp' {
  It 'returns 0 when the file is missing' {
    Read-DotfilesUpdateTimestamp -Path (Join-Path $TestDrive 'missing') | Should -Be 0
  }

  It 'returns 0 when the file holds garbage' {
    $path = Join-Path $TestDrive 'garbage'
    Set-Content -LiteralPath $path -Value 'not a number'
    Read-DotfilesUpdateTimestamp -Path $path | Should -Be 0
  }

  It 'reads the timestamp that Write-DotfilesUpdateTimestamp wrote' {
    $path = Join-Path $TestDrive 'written'
    Mock Get-DotfilesEpochNow { 1234567890 }
    Write-DotfilesUpdateTimestamp -Path $path
    Read-DotfilesUpdateTimestamp -Path $path | Should -Be 1234567890
  }
}

Describe 'Test-DotfilesUpToDate' {
  BeforeAll {
    $script:stamp = Join-Path $TestDrive 'stamp'
    Set-Content -LiteralPath $stamp -Value '1000'
  }

  It 'is up to date within a day of the last update' {
    Test-DotfilesUpToDate -TimestampFile $stamp -Now (1000 + 86399) | Should -BeTrue
  }

  It 'is stale a day after the last update' {
    Test-DotfilesUpToDate -TimestampFile $stamp -Now (1000 + 86400) | Should -BeFalse
  }

  It 'is stale when there has never been an update' {
    Test-DotfilesUpToDate -TimestampFile (Join-Path $TestDrive 'none') | Should -BeFalse
  }
}

Describe 'Request-DotfilesUpdate' {
  BeforeEach {
    Mock Start-Process {}
    $env:DOTFILES_SKIP_UPDATE = $null
  }

  It 'starts a hidden update when stale' {
    Request-DotfilesUpdate -DotfilesDir $TestDrive -TimestampFile (Join-Path $TestDrive 'none')
    Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
      $WindowStyle -eq 'Hidden' -and ($ArgumentList -join ' ') -like '*update.ps1*'
    }
  }

  It 'does nothing when up to date' {
    $stamp = Join-Path $TestDrive 'fresh'
    Write-DotfilesUpdateTimestamp -Path $stamp
    Request-DotfilesUpdate -DotfilesDir $TestDrive -TimestampFile $stamp
    Should -Invoke Start-Process -Times 0 -Exactly
  }

  It 'does nothing when DOTFILES_SKIP_UPDATE is set' {
    $env:DOTFILES_SKIP_UPDATE = '1'
    try {
      Request-DotfilesUpdate -DotfilesDir $TestDrive -TimestampFile (Join-Path $TestDrive 'none')
    } finally {
      $env:DOTFILES_SKIP_UPDATE = $null
    }
    Should -Invoke Start-Process -Times 0 -Exactly
  }
}

Describe 'Open-DotfilesUpdateLock' {
  It 'lets only one holder in, and frees the lock on dispose' {
    $path = Join-Path $TestDrive 'lock'
    $first = Open-DotfilesUpdateLock -Path $path
    try {
      $first | Should -Not -BeNullOrEmpty
      Open-DotfilesUpdateLock -Path $path | Should -BeNullOrEmpty
    } finally {
      $first.Dispose()
    }
    $again = Open-DotfilesUpdateLock -Path $path
    $again | Should -Not -BeNullOrEmpty
    $again.Dispose()
    Test-Path -LiteralPath $path | Should -BeTrue
  }
}

Describe 'Update-DotfilesRepo' {
  It 'fetches, then rebases onto origin/master' {
    Mock git { $global:LASTEXITCODE = 0 }
    Update-DotfilesRepo -DotfilesDir $TestDrive | Should -BeTrue
    Should -Invoke git -Times 1 -Exactly -ParameterFilter { $args -contains 'fetch' }
    Should -Invoke git -Times 1 -Exactly -ParameterFilter {
      $args -contains 'rebase' -and $args -contains 'origin/master'
    }
  }

  It 'stops when the fetch fails' {
    Mock git { $global:LASTEXITCODE = 1 }
    Update-DotfilesRepo -DotfilesDir $TestDrive -WarningAction SilentlyContinue |
      Should -BeFalse
    Should -Invoke git -Times 0 -Exactly -ParameterFilter { $args -contains 'rebase' }
  }

  It 'reports a failed rebase and aborts it' {
    Mock git { $global:LASTEXITCODE = if ($args -contains 'rebase') { 1 } else { 0 } }
    Update-DotfilesRepo -DotfilesDir $TestDrive -WarningAction SilentlyContinue |
      Should -BeFalse
    Should -Invoke git -Times 1 -Exactly -ParameterFilter {
      $args -contains 'rebase' -and $args -contains '--abort'
    }
  }
}

Describe 'Sync-DotfilesCodexSettings' {
  It 'applies an updated repo status line without replacing local settings' {
    $repo = Join-Path $TestDrive 'repo'
    $distDir = Join-Path $repo '.codex'
    $settings = Join-Path $TestDrive 'home' '.codex' 'config.toml'
    $null = New-Item -ItemType Directory -Force -Path $distDir, (Split-Path -Parent $settings)
    Set-Content -LiteralPath (Join-Path $distDir 'config.toml.dist') -Value @(
      '[tui]', 'status_line = ["current-dir"]'
    )
    Set-Content -LiteralPath $settings -Value @(
      '[tui]', 'status_line = ["model"]', 'theme = "dark"'
    )

    Sync-DotfilesCodexSettings -DotfilesDir $repo -Settings $settings

    Get-Content $settings | Should -Be @(
      '[tui]', 'status_line = ["current-dir"]', 'theme = "dark"'
    )
  }
}

Describe 'Invoke-DotfilesUpdate' {
  BeforeEach {
    $script:dir = Join-Path $TestDrive ([guid]::NewGuid())
    $null = New-Item -ItemType Directory -Path $dir
    # A stub setup.ps1 that records that it ran.
    Set-Content -LiteralPath (Join-Path $dir 'setup.ps1') `
      -Value "param([switch]`$SkipInstall); Set-Content '$dir\setup-ran' `$SkipInstall"
    $script:stamp = Join-Path $dir 'stamp'
    $script:lock = Join-Path $dir 'lock'
    Mock Update-DotfilesTools {}
    Mock Update-DotfilesRepo { $true }
    Mock Sync-DotfilesCodexSettings {}
  }

  It 'reruns setup without installs when HEAD moved, then updates tools' {
    $script:heads = [Collections.Queue]@('aaa', 'bbb')
    Mock Get-DotfilesHead { $script:heads.Dequeue() }
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    Get-Content (Join-Path $dir 'setup-ran') | Should -Be 'True'
    Test-DotfilesUpToDate -TimestampFile $stamp | Should -BeTrue
    Should -Invoke Update-DotfilesTools -Times 1 -Exactly
  }

  It 'syncs Codex settings without rerunning setup when HEAD did not move' {
    Mock Get-DotfilesHead { 'aaa' }
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    Test-Path (Join-Path $dir 'setup-ran') | Should -BeFalse
    Should -Invoke Sync-DotfilesCodexSettings -Times 1 -Exactly -ParameterFilter {
      $DotfilesDir -eq $dir
    }
    Should -Invoke Update-DotfilesTools -Times 1 -Exactly
  }

  It 'retries in an hour when the repo update fails' {
    Mock Update-DotfilesRepo { $false }
    Mock Get-DotfilesHead { 'aaa' }
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    $now = Get-DotfilesEpochNow
    Test-DotfilesUpToDate -TimestampFile $stamp -Now $now | Should -BeTrue
    Test-DotfilesUpToDate -TimestampFile $stamp -Now ($now + 3601) | Should -BeFalse
    Should -Invoke Update-DotfilesTools -Times 0 -Exactly
  }

  It 'does nothing when another update already ran' {
    Write-DotfilesUpdateTimestamp -Path $stamp
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    Should -Invoke Update-DotfilesRepo -Times 0 -Exactly
  }

  It 'does nothing while another update holds the lock' {
    $held = Open-DotfilesUpdateLock -Path $lock
    try {
      Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    } finally {
      $held.Dispose()
    }
    Should -Invoke Update-DotfilesRepo -Times 0 -Exactly
  }
}
