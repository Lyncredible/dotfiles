# PowerShell versions of ~/.dotfiles/.aliases, dot-sourced by profile.ps1. Keep them in sync:
# spec/powershell/aliases.Tests.ps1 fails when .aliases gains a name that is neither here nor
# in $DotfilesZshOnlyAliases.
# These are functions because PowerShell aliases cannot take arguments.

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

# The oh-my-zsh git plugin aliases that main.zshrc loads through antigen, limited to the ones
# in use. Same definitions as plugins/git/git.plugin.zsh.
$DotfilesGitAliases = @('gst', 'gl', 'gco', 'gcm', 'glg')

function gst { & git status @args }
function gl { & git pull @args }
function gco { & git checkout @args }
function gcm { & git checkout (Get-GitMainBranch) @args }
function glg { & git log --stat @args }

# Port of git_main_branch from the oh-my-zsh git plugin: the first of these local or remote
# branches that exists, then the remote's HEAD, then master.
function Get-GitMainBranch {
  & git rev-parse --git-dir *> $null
  if ($LASTEXITCODE -ne 0) { return }
  $names = 'main', 'trunk', 'mainline', 'default', 'stable', 'master'
  foreach ($prefix in 'refs/heads', 'refs/remotes/origin', 'refs/remotes/upstream') {
    foreach ($name in $names) {
      & git show-ref -q --verify "$prefix/$name"
      if ($LASTEXITCODE -eq 0) { return $name }
    }
  }
  foreach ($remote in 'origin', 'upstream') {
    $ref = & git rev-parse --abbrev-ref "$remote/HEAD" 2> $null
    if ($LASTEXITCODE -eq 0 -and "$ref" -like "$remote/*") {
      return "$ref".Substring($remote.Length + 1)
    }
  }
  return 'master'
}

# PowerShell resolves aliases before functions, so a built-in alias with the same name would
# hide a function above: gl is Get-Location and gcm is Get-Command. Drop any such alias.
foreach ($name in @('venv', 'act', 'dact', 'grpo', 'gbdm') + $DotfilesGitAliases) {
  if (Test-Path -LiteralPath "Alias:$name") {
    Remove-Item -LiteralPath "Alias:$name" -Force
  }
}
Remove-Variable name
