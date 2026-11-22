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
    $ported = @($names | Where-Object { $DotfilesZshOnlyAliases -notcontains $_ }) +
      $DotfilesGitAliases
    # Resolve the names the way the profile loads them: dot-sourced at global scope in a
    # fresh shell. A built-in alias with the same name would hide the function, and
    # Pester's own scope cannot remove AllScope aliases.
    $script = Join-Path $repo 'powershell\aliases.ps1'
    $command = "`$ProgressPreference = 'SilentlyContinue'; . '$script'; " +
      "foreach (`$n in '$($ported -join "','")') " +
      '{ "$n=$((Get-Command $n | Select-Object -First 1).CommandType)" }'
    $resolved = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -Command $command
    foreach ($name in $ported) {
      $resolved | Should -Contain "$name=Function" -Because "'$name' should run our function"
    }
  }
}

Describe 'Get-GitMainBranch' {
  BeforeAll {
    function New-TestRepo([string]$Name, [string]$Branch) {
      $dir = Join-Path $TestDrive $Name
      & git init -q -b $Branch $dir
      & git -C $dir -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
      return $dir
    }
  }

  It 'prefers main over master, like the oh-my-zsh helper' {
    $dir = New-TestRepo 'main-and-master' 'master'
    & git -C $dir branch main
    Push-Location $dir
    try { Get-GitMainBranch | Should -Be 'main' } finally { Pop-Location }
  }

  It 'finds master' {
    $dir = New-TestRepo 'master-only' 'master'
    Push-Location $dir
    try { Get-GitMainBranch | Should -Be 'master' } finally { Pop-Location }
  }

  It "falls back to the remote's HEAD branch" {
    $origin = New-TestRepo 'origin-develop' 'develop'
    $clone = Join-Path $TestDrive 'clone-develop'
    & git clone -q $origin $clone 2> $null
    Push-Location $clone
    try { Get-GitMainBranch | Should -Be 'develop' } finally { Pop-Location }
  }

  It 'returns nothing outside a repository' {
    $dir = Join-Path $TestDrive 'not-a-repo'
    $null = New-Item -ItemType Directory -Force -Path $dir
    $env:GIT_CEILING_DIRECTORIES = $TestDrive
    Push-Location $dir
    try {
      Get-GitMainBranch | Should -BeNullOrEmpty
    } finally {
      Pop-Location
      $env:GIT_CEILING_DIRECTORIES = $null
    }
  }
}

Describe 'git plugin aliases' {
  It 'gcm checks out the main branch' {
    $dir = Join-Path $TestDrive 'gcm'
    & git init -q -b main $dir
    Push-Location $dir
    try {
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
      & git checkout -q -b feature
      # Call the function itself: inside Pester's scope gcm is still Get-Command.
      & $function:gcm *> $null
      & git branch --show-current | Should -Be 'main'
    } finally { Pop-Location }
  }

  It 'passes arguments through' {
    $dir = Join-Path $TestDrive 'gco'
    & git init -q -b main $dir
    Push-Location $dir
    try {
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
      gco -q -b topic
      & git branch --show-current | Should -Be 'topic'
      (gst --short --branch) | Should -BeLike '## topic*'
    } finally { Pop-Location }
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
  It 'deletes merged branches but keeps the current branch, master, main, and dev' {
    $dir = Join-Path $TestDrive 'gbdm'
    & git init -q -b master $dir
    Push-Location $dir
    try {
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
      foreach ($branch in 'merged-a', 'merged-b', 'main', 'dev', 'develop-x') {
        & git branch $branch
      }
      & git checkout -q -b unmerged
      & git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
      & git checkout -q master
      gbdm *> $null
      $left = @(& git branch --format='%(refname:short)') | Sort-Object
      $left | Should -Be @('dev', 'main', 'master', 'unmerged')
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
