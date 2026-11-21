# Daily dotfiles update, started in a hidden process by Request-DotfilesUpdate.
# Output goes to ~/.dotfiles-update-pwsh.log because there is no console to show it.

. (Join-Path $PSScriptRoot 'common.ps1')

$log = Join-Path $HOME '.dotfiles-update-pwsh.log'
Start-Transcript -LiteralPath $log -Force | Out-Null
try {
  Invoke-DotfilesUpdate -DotfilesDir (Split-Path -Parent $PSScriptRoot)
} finally {
  Stop-Transcript | Out-Null
}
