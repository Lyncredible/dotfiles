# PowerShell versions of ~/.dotfiles/.aliases, dot-sourced by profile.ps1. Keep them in sync:
# spec/powershell/aliases.Tests.ps1 fails when .aliases gains a name that is neither here nor
# in $DotfilesZshOnlyAliases.
# These are functions because PowerShell aliases cannot take arguments.
# Keep this file ASCII: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.

# Aliases from .aliases with no Windows equivalent.
$DotfilesZshOnlyAliases = @(
  'aup'  # antigen update; the PowerShell side updates itself through update.ps1
)

function venv { & uv venv @args }

# Activate ./.venv. Activate.ps1 would replace the prompt, which oh-my-posh owns; the theme
# shows the venv instead, like p10k's virtualenv segment.
function act {
  $activate = Join-Path (Get-Location) '.venv\Scripts\Activate.ps1'
  if (-not (Test-Path -LiteralPath $activate)) {
    Write-Error "No virtualenv at $activate"
    return
  }
  $env:VIRTUAL_ENV_DISABLE_PROMPT = '1'
  . $activate
}

# Activate.ps1 defines a global `deactivate` function.
function dact { deactivate }

function rmo {
  Get-ChildItem -Recurse -Force -File -Filter '*.orig' | Remove-Item -Force
}

function grpo { & git remote prune origin @args }

# Delete local branches already merged into the current one, except the current branch,
# master, and dev.
function gbdm {
  $branches = @(& git branch --merged |
    Where-Object { $_ -notmatch '(^\*|master|dev)' } |
    ForEach-Object { $_.Trim() })
  if ($branches.Count -gt 0) {
    & git branch -d @branches
  }
}

# PowerShell resolves aliases before functions, and some names are built-in aliases
# (rmo is Remove-Module). Drop those so the functions above run.
foreach ($name in 'venv', 'act', 'dact', 'rmo', 'grpo', 'gbdm') {
  if (Test-Path -LiteralPath "Alias:$name") {
    Remove-Item -LiteralPath "Alias:$name" -Force
  }
}
Remove-Variable name
