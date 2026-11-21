## My dotfiles
Multi-platform development environment configuration for macOS, Linux, WSL, and Windows.

## Features
- **Shell**: Zsh with [antigen](https://github.com/zsh-users/antigen) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
- **Plugins**: Auto-suggestions, syntax highlighting, completions, git integration
- **Window Management**: Hammerspoon (macOS) and AutoHotkey (Windows) with unified keybindings
- **Terminal Emulators**: Ghostty, iTerm2, Terminal.app configurations
- **Keyboard Remapping**: Karabiner-Elements for RDP/remote desktop workflows
- **Development Tools**: Git, Vim, Tmux configs with NVM, rbenv, Go, Python support
- **AI Integration**: Claude Code configuration with custom instructions and settings
- **Agent Skills**: Repo-managed skills installed to `~/.agents/skills`
- **Auto-Update**: Automatic dotfiles and plugin updates every 24 hours
- **Non-Destructive**: Preserves local customizations via `~/.zshrc_pre` and `~/.zshrc_post`

## Installation
Clone in HTTPS mode
```
sh -c "$(curl -sL --proto-redir -all,https https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.sh)"
```
Clone in SSH mode
```
sh -c "$(curl -sL --proto-redir -all,https https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.sh)" - -s
```

### Windows (PowerShell 7)
Run from any PowerShell, including the built-in Windows PowerShell 5.1. Installs git and
PowerShell 7 (`pwsh`) if needed, clones to `~\.dotfiles`, and runs `setup.ps1` with pwsh. That
points the pwsh `$PROFILE` at `powershell\profile.ps1` and Ghostty at the shared config, installs
oh-my-posh, fzf, PSFzf, AutoHotkey, and the Meslo Nerd Font, and runs `init.ahk` at logon. The
prompt and colors mirror `.p10k.zsh` and zsh-syntax-highlighting. Windows PowerShell 5.1 does not
load the profile; open `pwsh` instead.
```
irm https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.ps1 | iex
```
Clone in SSH mode
```
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.ps1))) -Ssh
```
Local changes go in `~\.pwsh_pre.ps1` and `~\.pwsh_post.ps1`. Updates run once a day in a
hidden process and log to `~\.dotfiles-update-pwsh.log`.

## Testing
Requires [shellspec](https://shellspec.info/) (`brew install shellspec`).
```
make check              # lint + test + integration tests
make test               # unit tests only
make lint               # shellcheck + line length
```
Pass `FILES=` to target specific files:
```
make test FILES=spec/tmux_sysstat_spec.sh
make lint FILES=.local/bin/tmux-sysstat
```
PowerShell tests run in pwsh and need Pester 5 or later
(`Install-PSResource Pester -Repository PSGallery -Scope CurrentUser`):
```
Invoke-Pester spec/powershell   # or: make test-powershell
```

## Agent Skills
- `add-lync-skill`: Add or update a skill in this repo, even when the agent is
  running from another working directory, then commit and push it.
