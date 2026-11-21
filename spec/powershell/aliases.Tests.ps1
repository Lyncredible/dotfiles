# Pester 5 tests for powershell/aliases.ps1. Run: Invoke-Pester spec/powershell

BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\powershell\aliases.ps1')
  $script:repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

Describe 'alias parity with .aliases' {
  It 'ports every zsh alias, or lists it as zsh-only' {
    $names = Get-Content (Join-Path $repo '.aliases') |
      Where-Object { $_ -match '^alias ([^=]+)=' } |
      ForEach-Object { $Matches[1] }
    $names | Should -Not -BeNullOrEmpty
    $ported = @($names | Where-Object { $DotfilesZshOnlyAliases -notcontains $_ })
    # Resolve the names the way the profile loads them: dot-sourced at global scope in a
    # fresh shell. A built-in alias (rmo is Remove-Module) would hide the function, and
    # Pester's own scope cannot remove AllScope aliases.
    $script = Join-Path $repo 'powershell\aliases.ps1'
    $command = "`$ProgressPreference = 'SilentlyContinue'; . '$script'; " +
      "foreach (`$n in '$($ported -join "','")') " +
      '{ "$n=$((Get-Command $n | Select-Object -First 1).CommandType)" }'
    $shell = (Get-Process -Id $PID).Path
    # -EncodedCommand: Windows PowerShell 5.1 drops the double quotes in a -Command argument.
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $resolved = & $shell -NoProfile -NonInteractive -EncodedCommand $encoded
    foreach ($name in $ported) {
      $resolved | Should -Contain "$name=Function" -Because "'$name' is in .aliases"
    }
  }
}

Describe 'rmo' {
  It 'deletes .orig files recursively, including hidden ones, and nothing else' {
    $dir = Join-Path $TestDrive 'rmo'
    $null = New-Item -ItemType Directory -Force -Path "$dir\sub"
    Set-Content "$dir\a.orig" 'x'
    Set-Content "$dir\sub\b.orig" 'x'
    Set-Content "$dir\keep.txt" 'x'
    $hidden = New-Item -ItemType File -Path "$dir\sub\c.orig" -Value 'x'
    $hidden.Attributes = 'Hidden'
    Push-Location $dir
    # Call the function itself; the parity test covers the built-in rmo alias.
    try { & $function:rmo } finally { Pop-Location }
    @(Get-ChildItem $dir -Recurse -Force -File).Name | Should -Be @('keep.txt')
  }
}

Describe 'act' {
  It 'dot-sources .venv\Scripts\Activate.ps1 without letting it replace the prompt' {
    $dir = Join-Path $TestDrive 'venv'
    $null = New-Item -ItemType Directory -Force -Path "$dir\.venv\Scripts"
    Set-Content "$dir\.venv\Scripts\Activate.ps1" `
      '$env:ACT_TEST_PROMPT = $env:VIRTUAL_ENV_DISABLE_PROMPT'
    $env:ACT_TEST_PROMPT = $null
    $env:VIRTUAL_ENV_DISABLE_PROMPT = $null
    Push-Location $dir
    try { act } finally { Pop-Location }
    $env:ACT_TEST_PROMPT | Should -Be '1'
    $env:ACT_TEST_PROMPT = $null
    $env:VIRTUAL_ENV_DISABLE_PROMPT = $null
  }

  It 'reports a missing virtualenv' {
    Push-Location $TestDrive
    try {
      { $ErrorActionPreference = 'Stop'; act } | Should -Throw '*No virtualenv*'
    } finally { Pop-Location }
  }
}

Describe 'gbdm' {
  It 'deletes merged branches but keeps the current branch, master, and dev' {
    $dir = Join-Path $TestDrive 'gbdm'
    & git init -q -b master $dir
    Push-Location $dir
    try {
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
      foreach ($branch in 'merged-a', 'merged-b', 'dev', 'develop-x') { & git branch $branch }
      & git checkout -q -b unmerged
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
      & git checkout -q master
      gbdm *> $null
      $left = @(& git branch --format='%(refname:short)') | Sort-Object
      # develop-x matches "dev", which the zsh alias also keeps.
      $left | Should -Be @('dev', 'develop-x', 'master', 'unmerged')
    } finally { Pop-Location }
  }

  It 'does nothing when no branch is merged' {
    $dir = Join-Path $TestDrive 'gbdm-none'
    & git init -q -b master $dir
    Push-Location $dir
    try {
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
      # Without the guard, `git branch -d` with no names fails with "branch name required".
      $out = gbdm 2>&1
      $out | Should -BeNullOrEmpty
      @(& git branch --format='%(refname:short)') | Should -Be @('master')
    } finally { Pop-Location }
  }
}
