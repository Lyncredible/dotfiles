# Windows counterpart of install.sh: install git and PowerShell 7, clone this repo, then run
# setup.ps1 with pwsh. Run it from any PowerShell, including Windows PowerShell 5.1:
#   irm https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.ps1 | iex
# Clone over SSH instead of HTTPS:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.ps1))) -Ssh
# This is the one script that must still run in Windows PowerShell 5.1, the only PowerShell
# on a fresh machine. Keep it ASCII (5.1 reads BOM-less scripts as ANSI) and 5.1 syntax only.
param(
  [switch]$Ssh
)

$ErrorActionPreference = 'Stop'

function Update-SessionPath {
  $env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'User')
  ) -join ';'
}

function Install-WingetPackage {
  param([string]$Id, [string]$Command)
  if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "$Command is not installed, and winget is not available to install it."
  }
  Write-Host "Installing $Id..."
  & winget install --id $Id --exact --silent --disable-interactivity `
    --accept-package-agreements --accept-source-agreements
  Update-SessionPath
  if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
    throw "Installed $Id, but $Command is still not on PATH. Open a new terminal and rerun."
  }
}

function Install-Dotfiles {
  param([switch]$Ssh)
  $dotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }

  Install-WingetPackage -Id 'Git.Git' -Command 'git'
  Install-WingetPackage -Id 'Microsoft.PowerShell' -Command 'pwsh'

  if ($Ssh) {
    $cloneUrl = 'git@github.com:Lyncredible/dotfiles.git'
  } else {
    $cloneUrl = 'https://github.com/Lyncredible/dotfiles.git'
  }
  & git clone $cloneUrl $dotfilesDir
  if ($LASTEXITCODE -ne 0) { throw 'Failed to clone dotfiles repo.' }

  # Bypass only for this run; setup.ps1 sets a lasting CurrentUser policy for the profile.
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dotfilesDir 'setup.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'setup.ps1 failed.' }
}

Install-Dotfiles -Ssh:$Ssh
