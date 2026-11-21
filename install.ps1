# Windows counterpart of install.sh: clone this repo, then run setup.ps1.
#   irm https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.ps1 | iex
# Clone over SSH instead of HTTPS:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.ps1))) -Ssh
# Keep this file ASCII: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
param(
  [switch]$Ssh
)

$ErrorActionPreference = 'Stop'

function Install-Dotfiles {
  param([switch]$Ssh)
  $dotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
      throw 'git is not installed, and winget is not available to install it.'
    }
    Write-Host 'Installing git...'
    & winget install --id Git.Git --exact --silent --disable-interactivity `
      --accept-package-agreements --accept-source-agreements
    $env:Path = @(
      [Environment]::GetEnvironmentVariable('Path', 'Machine'),
      [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'
  }

  if ($Ssh) {
    $cloneUrl = 'git@github.com:Lyncredible/dotfiles.git'
  } else {
    $cloneUrl = 'https://github.com/Lyncredible/dotfiles.git'
  }
  & git clone $cloneUrl $dotfilesDir
  if ($LASTEXITCODE -ne 0) { throw 'Failed to clone dotfiles repo.' }

  # Only this process: setup.ps1 sets a lasting CurrentUser policy for the profile.
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  & (Join-Path $dotfilesDir 'setup.ps1')
}

Install-Dotfiles -Ssh:$Ssh
