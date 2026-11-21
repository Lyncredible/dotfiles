# Pester 5 tests for powershell/common.ps1. Run: Invoke-Pester spec/powershell

BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\powershell\common.ps1')
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

  It 'reports a failed rebase' {
    Mock git { $global:LASTEXITCODE = if ($args -contains 'rebase') { 1 } else { 0 } }
    Update-DotfilesRepo -DotfilesDir $TestDrive -WarningAction SilentlyContinue |
      Should -BeFalse
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
  }

  It 'reruns setup without installs when HEAD moved, then updates tools' {
    $script:heads = [Collections.Queue]@('aaa', 'bbb')
    Mock Get-DotfilesHead { $script:heads.Dequeue() }
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    Get-Content (Join-Path $dir 'setup-ran') | Should -Be 'True'
    Test-DotfilesUpToDate -TimestampFile $stamp | Should -BeTrue
    Should -Invoke Update-DotfilesTools -Times 1 -Exactly
  }

  It 'skips setup when HEAD did not move' {
    Mock Get-DotfilesHead { 'aaa' }
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    Test-Path (Join-Path $dir 'setup-ran') | Should -BeFalse
    Should -Invoke Update-DotfilesTools -Times 1 -Exactly
  }

  It 'leaves the timestamp alone when the repo update fails' {
    Mock Update-DotfilesRepo { $false }
    Mock Get-DotfilesHead { 'aaa' }
    Invoke-DotfilesUpdate -DotfilesDir $dir -TimestampFile $stamp -LockFile $lock
    Test-Path $stamp | Should -BeFalse
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
