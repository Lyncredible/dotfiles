# Shared PowerShell profile, dot-sourced by the $PROFILE wrapper that setup.ps1 writes.
# Local changes go in ~/.pwsh_pre.ps1 or ~/.pwsh_post.ps1, not here.
# Keep this file ASCII: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.

. (Join-Path $PSScriptRoot 'common.ps1')
Request-DotfilesUpdate -DotfilesDir (Split-Path -Parent $PSScriptRoot)

Import-Module PSReadLine
try {
  # Fails when output is redirected or the console has no VT support.
  Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
} catch {}
Set-PSReadLineKeyHandler -Key Tab -Function Complete

# Match the zsh-autosuggestions and zsh-syntax-highlighting defaults that main.zshrc loads.
# Windows PowerShell 5.1 has no `e escape.
$esc = [char]27
Set-PSReadLineOption -Colors @{
  InlinePrediction = "$esc[90m"   # autosuggest: fg=8
  Command          = "$esc[32m"   # command/builtin/alias/function: fg=green
  Keyword          = "$esc[33m"   # reserved-word: fg=yellow
  String           = "$esc[33m"   # quoted arguments: fg=yellow
  Comment          = "$esc[1;30m" # comment: fg=black,bold
  Error            = "$esc[1;31m" # unknown-token: fg=red,bold
  Default          = "$esc[39m"   # everything else is unstyled
  Parameter        = "$esc[39m"
  Variable         = "$esc[39m"
  Operator         = "$esc[39m"
  Number           = "$esc[39m"
  Member           = "$esc[39m"
  Type             = "$esc[39m"
}
Remove-Variable esc

# PSFzf needs the fzf executable on PATH; oh-my-posh must be installed. Skip each if missing.
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and
    (Get-Module -ListAvailable PSFzf)) {
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  # Mirrors .p10k.zsh. Colors are palette indexes so they follow the terminal theme.
  oh-my-posh init pwsh --config (Join-Path $PSScriptRoot 'p10k.omp.json') | Invoke-Expression
}
