# Port of merge_codex_settings in common.sh. Manage root keys and the two status line
# keys in [tui]; leave other table settings alone.
function Merge-CodexSettings {
  param(
    [Parameter(Mandatory)][string]$Dist,
    [Parameter(Mandatory)][string]$Settings
  )
  if (-not (Test-Path -LiteralPath $Dist)) { return }
  $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Settings)
  if (-not (Test-Path -LiteralPath $Settings)) {
    Copy-Item -LiteralPath $Dist -Destination $Settings
    return
  }
  $tablePattern = '^\s*\['
  $tuiPattern = '^\s*\[tui\]\s*(#.*)?$'
  $arrayEndPattern = '^[^#]*\]\s*(#.*)?$'
  $managed = @{ root = [ordered]@{}; tui = [ordered]@{}; other = [ordered]@{} }
  $written = @{
    root = [Collections.Generic.HashSet[string]]::new()
    tui = [Collections.Generic.HashSet[string]]::new()
    other = [Collections.Generic.HashSet[string]]::new()
  }
  $settingKey = {
    param($Line, $Section)
    if ($Line -cmatch '^\s*([A-Za-z0-9_-]+)\s*=') {
      $key = $Matches[1]
      if ($Section -eq 'root' -or
          ($Section -eq 'tui' -and $key -cmatch '^status_line(_use_colors)?$')) {
        $key
      }
    }
  }
  $section = 'root'
  foreach ($line in [IO.File]::ReadAllLines($Dist)) {
    if ($line -match $tablePattern) {
      $section = if ($line -cmatch $tuiPattern) { 'tui' } else { 'other' }
    }
    $key = & $settingKey $line $section
    if ($key -and -not $managed[$section].Contains($key)) {
      $managed[$section][$key] = $line
    }
  }
  $lines = [Collections.Generic.List[string]]::new()
  $writeMissing = {
    param($Section)
    foreach ($key in $managed[$Section].Keys) {
      if ($written[$Section].Add($key)) { $lines.Add($managed[$Section][$key]) }
    }
  }
  $section = 'root'
  $sawTui = $false
  $skippingStatusArray = $false
  foreach ($line in [IO.File]::ReadAllLines($Settings)) {
    if ($skippingStatusArray) {
      if ($line -match $arrayEndPattern) { $skippingStatusArray = $false }
      continue
    }
    if ($line -match $tablePattern) {
      & $writeMissing $section
      $section = if ($line -cmatch $tuiPattern) { 'tui' } else { 'other' }
      if ($section -eq 'tui') { $sawTui = $true }
    }
    $key = & $settingKey $line $section
    if ($key -and $managed[$section].Contains($key)) {
      if ($written[$section].Add($key)) { $lines.Add($managed[$section][$key]) }
      if ($section -eq 'tui' -and $key -eq 'status_line' -and
          $line -match '^[^=]*=\s*\[' -and $line -notmatch $arrayEndPattern) {
        $skippingStatusArray = $true
      }
      continue
    }
    $lines.Add($line)
  }
  & $writeMissing $section
  if (-not $sawTui -and $managed['tui'].Count) {
    $lines.Add('')
    $lines.Add('[tui]')
    & $writeMissing 'tui'
  }
  $text = ($lines -join "`n") + "`n"
  if ($text -ne [IO.File]::ReadAllText($Settings)) {
    [IO.File]::WriteAllText($Settings, $text, [Text.UTF8Encoding]::new($false))
  }
}

# Setup, profile startup, and scheduled updates can overlap. Let the first sync finish.
function Sync-DotfilesCodexSettings {
  param(
    [Parameter(Mandatory)][string]$DotfilesDir,
    [string]$Settings = (Join-Path $HOME '.codex\config.toml')
  )
  $dist = Join-Path $DotfilesDir '.codex\config.toml.dist'
  if (-not (Test-Path -LiteralPath $dist)) { return }

  $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Settings) -ErrorAction Stop
  $lock = Open-DotfilesUpdateLock -Path "$Settings.dotfiles.lock"
  if ($null -eq $lock) { return }
  try {
    Merge-CodexSettings -Dist $dist -Settings $Settings
  } finally {
    $lock.Dispose()
  }
}
