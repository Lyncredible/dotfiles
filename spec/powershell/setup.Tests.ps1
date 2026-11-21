# Pester 5 tests for setup.ps1. Run: Invoke-Pester spec/powershell

BeforeAll {
  # Dot-sourcing loads the functions without running Invoke-Setup.
  . (Join-Path $PSScriptRoot '..\..\setup.ps1')
}

Describe 'Get-ProfileWrapper' {
  It 'dot-sources the repo profile between the local pre and post files' {
    $lines = (Get-ProfileWrapper -DotfilesDir 'C:\dots') -split "`r`n"
    $lines[0] | Should -BeLike "$ProfileWrapperHeader*"
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
