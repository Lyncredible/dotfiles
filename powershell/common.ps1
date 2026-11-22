# Shared PowerShell helpers for profile.ps1, update.ps1, and setup.ps1. PowerShell 7 (pwsh)
# only; install.ps1 is the one script that must also run in Windows PowerShell 5.1.

# Windows tools. Setup skips a package when its Command is on PATH or one of its Paths exists.
$AutoHotkeyPaths = @(
  "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
  "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey.exe"
)
$DotfilesWingetPackages = @(
  # install.ps1 installs this one first, since setup.ps1 needs it to run.
  [pscustomobject]@{ Id = 'Microsoft.PowerShell'; Command = 'pwsh'; Paths = @() }
  [pscustomobject]@{ Id = 'JanDeDobbeleer.OhMyPosh'; Command = 'oh-my-posh'; Paths = @() }
  [pscustomobject]@{ Id = 'junegunn.fzf'; Command = 'fzf'; Paths = @() }
  # The venv alias runs uv.
  [pscustomobject]@{ Id = 'astral-sh.uv'; Command = 'uv'; Paths = @() }
  # init.ahk: window management, mirroring .hammerspoon on macOS.
  [pscustomobject]@{ Id = 'AutoHotkey.AutoHotkey'; Command = $null; Paths = $AutoHotkeyPaths }
)

function Test-DotfilesPackageInstalled {
  param([Parameter(Mandatory)]$Package)
  if ($Package.Command -and (Get-Command $Package.Command -ErrorAction SilentlyContinue)) {
    return $true
  }
  foreach ($path in $Package.Paths) {
    if (Test-Path -LiteralPath $path) { return $true }
  }
  return $false
}

# The tools main.zshrc warns about when missing: uv (unless NO_UV is true) and fzf.
function Get-DotfilesMissingTools {
  $missing = @()
  if ($env:NO_UV -ne 'true' -and -not (Get-Command uv -ErrorAction SilentlyContinue)) {
    $missing += 'uv'
  }
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { $missing += 'fzf' }
  return $missing
}

function Find-AutoHotkey {
  foreach ($path in $AutoHotkeyPaths) {
    if (Test-Path -LiteralPath $path) { return $path }
  }
  return $null
}

# PowerShell Gallery modules. PSReadLine is not listed: PowerShell 7 ships a current one.
$DotfilesModules = @(
  [pscustomobject]@{ Name = 'PSFzf'; MinimumVersion = [version]'2.0.0' }
)

function Get-DotfilesDefaultDir {
  if ($env:DOTFILES_DIR) { return $env:DOTFILES_DIR }
  return (Join-Path $HOME '.dotfiles')
}

# PowerShell port of .local/bin/whereami, which sets WHEREAMI for the zsh tab title: the
# machine's name and an emoji. spec/whereami_spec.sh covers the original.
function Get-DotfilesStringIndex {
  param([Parameter(Mandatory)][string]$String, [Parameter(Mandatory)][int]$Modulo)
  [long]$hash = 0
  foreach ($char in $String.ToCharArray()) {
    $hash = ($hash * 31 + [int]$char) % 2147483647
  }
  return [int]($hash % $Modulo)
}

function Get-DotfilesWhereami {
  param([string]$Script = (Join-Path (Split-Path -Parent $PSScriptRoot) '.local\bin\whereami'))
  $resolver = Get-Command whereami-resolve -CommandType Application -ErrorAction SilentlyContinue
  $name = $null
  $emoji = $null
  if ($resolver) {
    $name = (& $resolver 2> $null | Select-Object -First 1)
    $emoji = (& $resolver --emoji 2> $null | Select-Object -First 1)
  }
  # GetHostName keeps the case `hostname` prints; COMPUTERNAME is upper case, a different hash.
  if (-not $name) { $name = ([Net.Dns]::GetHostName() -split '\.')[0] }
  if (-not $emoji -and (Test-Path -LiteralPath $Script)) {
    # Read the list from the script so the two can't drift apart.
    $line = Select-String -LiteralPath $Script -Pattern '^\s*emojis="(.*)"' -Encoding utf8 |
      Select-Object -First 1
    if ($line) {
      $emojis = $line.Matches[0].Groups[1].Value -split ' '
      # The script takes the hash modulo 75, not the list's length.
      $emoji = $emojis[(Get-DotfilesStringIndex -String $name -Modulo 75)]
    }
  }
  if ($emoji) { return "$name $emoji" }
  return $name
}

function Get-DotfilesEpochNow {
  return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

function Read-DotfilesUpdateTimestamp {
  param([Parameter(Mandatory)][string]$Path)
  if (Test-Path -LiteralPath $Path) {
    $raw = Get-Content -LiteralPath $Path -TotalCount 1
    $value = 0L
    if ([long]::TryParse("$raw".Trim(), [ref]$value)) { return $value }
  }
  return 0L
}

function Write-DotfilesUpdateTimestamp {
  param([Parameter(Mandatory)][string]$Path)
  [IO.File]::WriteAllText($Path, "$(Get-DotfilesEpochNow)`n")
}

function Test-DotfilesUpToDate {
  param(
    [Parameter(Mandatory)][string]$TimestampFile,
    [long]$Now = (Get-DotfilesEpochNow),
    [long]$Frequency = 86400
  )
  return $Now -lt ((Read-DotfilesUpdateTimestamp -Path $TimestampFile) + $Frequency)
}

# Called from the profile. Never blocks the prompt: the update runs in a hidden process.
function Request-DotfilesUpdate {
  param(
    [string]$DotfilesDir = (Get-DotfilesDefaultDir),
    [string]$TimestampFile = (Join-Path $HOME '.dotfiles-update-pwsh')
  )
  if ($env:DOTFILES_SKIP_UPDATE) { return }
  if (Test-DotfilesUpToDate -TimestampFile $TimestampFile) { return }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }

  $shell = (Get-Process -Id $PID).Path
  $script = Join-Path $DotfilesDir 'powershell\update.ps1'
  Start-Process -FilePath $shell -WindowStyle Hidden -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`""
  )
}

# Returns an open handle, or $null when another update holds the lock.
# Never delete the lock file; the OS releases the handle when the process exits.
function Open-DotfilesUpdateLock {
  param([Parameter(Mandatory)][string]$Path)
  try {
    return [IO.File]::Open(
      $Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  } catch [IO.IOException] {
    return $null
  }
}

function Get-DotfilesHead {
  param([Parameter(Mandatory)][string]$DotfilesDir)
  return (& git -C $DotfilesDir rev-parse --verify HEAD 2>$null)
}

# Same contract as dotfiles_update_repo in common.sh: fetch, then rebase onto origin/master.
function Update-DotfilesRepo {
  param([Parameter(Mandatory)][string]$DotfilesDir)
  & git -C $DotfilesDir fetch --quiet
  if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Failed to fetch dotfiles repo.'
    return $false
  }
  & git -C $DotfilesDir rebase --quiet origin/master
  if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Failed to rebase dotfiles repo.'
    return $false
  }
  return $true
}

# The PowerShell counterpart of `antigen update`: upgrade the prompt's tools.
function Update-DotfilesTools {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    foreach ($package in $DotfilesWingetPackages) {
      & winget upgrade --id $package.Id --exact --silent --disable-interactivity `
        --accept-package-agreements --accept-source-agreements | Out-Null
    }
  }
  foreach ($module in $DotfilesModules) {
    try {
      Update-PSResource -Name $module.Name -Repository PSGallery -Scope CurrentUser `
        -TrustRepository -ErrorAction Stop
    } catch {
      Write-Warning "Failed to update module $($module.Name): $_"
    }
  }
}

function Invoke-DotfilesUpdate {
  param(
    [string]$DotfilesDir = (Get-DotfilesDefaultDir),
    [string]$TimestampFile = (Join-Path $HOME '.dotfiles-update-pwsh'),
    [string]$LockFile = (Join-Path $HOME '.dotfiles-update-pwsh.lock')
  )
  $lock = Open-DotfilesUpdateLock -Path $LockFile
  if ($null -eq $lock) { return }
  try {
    # Another shell may have finished an update while this one was starting.
    if (Test-DotfilesUpToDate -TimestampFile $TimestampFile) { return }

    $before = Get-DotfilesHead -DotfilesDir $DotfilesDir
    if (-not (Update-DotfilesRepo -DotfilesDir $DotfilesDir)) { return }
    $after = Get-DotfilesHead -DotfilesDir $DotfilesDir
    Write-DotfilesUpdateTimestamp -Path $TimestampFile

    if ($before -ne $after) {
      & (Join-Path $DotfilesDir 'setup.ps1') -SkipInstall
    }
    Update-DotfilesTools
  } finally {
    $lock.Dispose()
  }
}
