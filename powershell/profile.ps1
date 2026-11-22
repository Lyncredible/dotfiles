# Shared PowerShell profile, dot-sourced by the $PROFILE wrapper that setup.ps1 writes.
# Local changes go in ~/.pwsh_pre.ps1 or ~/.pwsh_post.ps1, not here. PowerShell 7 only.

. (Join-Path $PSScriptRoot 'common.ps1')
Request-DotfilesUpdate -DotfilesDir (Split-Path -Parent $PSScriptRoot)
$editor = Get-DotfilesEditor
if ($editor) { $env:EDITOR = $editor }
Remove-Variable editor
# The tab title in p10k.omp.json uses it, as main.zshrc's does.
$env:WHEREAMI = Get-DotfilesWhereami
. (Join-Path $PSScriptRoot 'aliases.ps1')
foreach ($tool in Get-DotfilesMissingTools) { Write-Warning "$tool is not installed" }

Import-Module PSReadLine
try {
  # Fails when output is redirected or the console has no VT support.
  Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
} catch {}
Set-PSReadLineKeyHandler -Key Tab -Function Complete

# Match the zsh-autosuggestions and zsh-syntax-highlighting defaults that main.zshrc loads.
Set-PSReadLineOption -Colors @{
  InlinePrediction = "`e[90m"   # autosuggest: fg=8
  Command          = "`e[32m"   # command/builtin/alias/function: fg=green
  Keyword          = "`e[33m"   # reserved-word: fg=yellow
  String           = "`e[33m"   # quoted arguments: fg=yellow
  Comment          = "`e[1;30m" # comment: fg=black,bold
  Error            = "`e[1;31m" # unknown-token: fg=red,bold
  Default          = "`e[39m"   # everything else is unstyled
  Parameter        = "`e[39m"
  Variable         = "`e[39m"
  Operator         = "`e[39m"
  Number           = "`e[39m"
  Member           = "`e[39m"
  Type             = "`e[39m"
}

# PSFzf needs the fzf executable on PATH; oh-my-posh must be installed. Skip each if missing.
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and
    (Get-Module -ListAvailable PSFzf)) {
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  # Mirrors .p10k.zsh. Colors are palette indexes so they follow the terminal theme.
  oh-my-posh init pwsh --config (Join-Path $PSScriptRoot 'p10k.omp.json') | Invoke-Expression
}
