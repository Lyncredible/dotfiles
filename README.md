## My dotfiles
Multi-platform development environment configuration for macOS, Linux, WSL, and Windows.

## Features
- **Shell**: Zsh with [antigen](https://github.com/zsh-users/antigen) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
- **Plugins**: Auto-suggestions, syntax highlighting, completions, git integration
- **Window Management**: Hammerspoon (macOS) and AutoHotkey (Windows) with unified keybindings
- **Terminal Emulators**: Ghostty, iTerm2, Terminal.app configurations
- **Keyboard Remapping**: Karabiner-Elements for RDP/remote desktop workflows
- **Development Tools**: Git, Vim, Tmux configs with NVM, rbenv, Go, Python support
- **Auto-Update**: Automatic dotfiles and plugin updates every 24 hours
- **Non-Destructive**: Preserves local customizations via `~/.zshrc_local`

## Installation
Clone in HTTPS mode
```
sh -c "$(curl -sL --proto-redir -all,https https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.sh)"
```
Clone in SSH mode
```
sh -c "$(curl -sL --proto-redir -all,https https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.sh)" - -s
```
