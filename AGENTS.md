# AI Agent Documentation for .dotfiles Repository

## Purpose & Overview

This repository contains personal dotfiles for managing development environment configurations across multiple platforms (macOS, Linux, WSL, and Windows). It's designed for a developer who works across different operating systems and wants consistent tooling, keybindings, and workflows everywhere.

**Key Goals:**
- Consistent shell experience with zsh, plugins, and custom theme
- Unified window management and keyboard shortcuts across platforms
- Automated setup and self-updating configurations
- Non-destructive installation that preserves local customizations
- Development environment setup for Node, Ruby, Go, and Python

## Repository Structure

```
.dotfiles/
├── .hammerspoon/              # macOS Hammerspoon automation
│   ├── Spoons/                # Extensions (KSheet, ReloadConfiguration, SpoonInstall)
│   └── init.lua               # Window management, hotkeys, Spotify/Zoom controls
├── bin/                       # Custom executables
│   └── wslsubl                # WSL helper for Sublime Text
├── ghostty/                   # Ghostty terminal emulator config
│   └── config                 # Theme, font, keybindings
├── iterm2/                    # iTerm2 configuration
│   └── com.googlecode.iterm2.plist
├── karabiner/                 # Karabiner-Elements keyboard remapping
│   ├── karabiner.json         # RDP/remote desktop key remapping
│   └── automatic_backups/     # Config version history
├── Shell configuration files
│   ├── .zshrc                 # Entry point (sources main.zshrc + local)
│   ├── main.zshrc             # Primary zsh config with plugins
│   ├── .profile               # Login shell setup
│   ├── .aliases               # Shell aliases (venv, git shortcuts)
│   ├── .p10k.zsh              # Powerlevel10k theme configuration
│   ├── common.sh              # Shared utility functions
│   ├── .gitconfig             # Git global configuration
│   ├── .vimrc                 # Vim configuration
│   ├── .tmux.conf             # Tmux configuration
│   └── Pro.terminal           # Terminal.app profile
├── init.ahk                   # AutoHotkey v2.0 script for Windows
├── install.sh                 # Initial clone and setup
├── setup.sh                   # Symlink creation and plugin install
└── README.md                  # Installation instructions
```

## Key Components

### Shell Configuration (Zsh)

**Main Files:**
- `main.zshrc` - Primary configuration
- `.p10k.zsh` - Powerlevel10k prompt theme (two-line, rainbow colors)
- `.aliases` - Command shortcuts

**Plugin System:**
- **Antigen** - Plugin manager
- **oh-my-zsh plugins**: command-not-found, common-aliases, colored-man-pages, extract, git, sublime, z
- **zsh-users plugins**: zsh-autosuggestions, zsh-completions, zsh-syntax-highlighting

**Key Features:**
- Powerlevel10k with instant prompt for fast startup
- FZF integration for fuzzy finding
- SSH agent management in tmux sessions
- Custom `lynclone()` function for multi-key GitHub cloning
- Auto-suggestions with paste optimization

### Terminal Emulators

**Ghostty** (`ghostty/config`):
- Modern, GPU-accelerated terminal
- Dimmed Monokai theme
- MesloLGM Nerd Font, size 12
- Cmd+arrow keybindings for tab navigation

**iTerm2** (`iterm2/com.googlecode.iterm2.plist`):
- Comprehensive plist configuration
- Custom profiles and keybindings
- Cmd+Enter keybinding configured

**Terminal.app** (`Pro.terminal`):
- macOS default terminal profile
- 180 columns × 40 rows

### Window Management

**Hammerspoon** (`.hammerspoon/init.lua`) - macOS:
- **Window Snapping**: Left, Right, Top, Bottom, Max, Center, Middle
- **Thirds**: LeftThird, RightThird, LeftTwoThirds, RightTwoThirds
- **Ultra-wide Detection**: Adapts for 21:9+ displays
- **Multi-monitor**: Hyper+Arrow keys to move windows between screens
- **Application-specific**: iTerm2/Terminal retain size when moving
- **Hotkey Setup**:
  - BaseKey: Cmd+Ctrl
  - HyperKey: Cmd+Alt+Ctrl
  - UniversalKey: Various bindings
- **Integrations**:
  - Spotify: Cmd+Ctrl+S (play/pause), D (info), B (prev), F (next)
  - Zoom/Teams: Cmd+Ctrl+A (audio), V (video)
  - Coding Layout: Cmd+Ctrl+P
- **KSheet**: Keyboard shortcut overlay reference

**AutoHotkey** (`init.ahk`) - Windows:
- Mirrors Hammerspoon functionality
- Alt+Ctrl+Arrow keys for window snapping
- Ultra-wide monitor adaptation
- Multi-monitor support

### Keyboard Remapping

**Karabiner-Elements** (`karabiner/karabiner.json`):
- RDP/Remote Desktop key remapping
- Swaps Opt↔Cmd for seamless Windows/Mac switching
- Supports Microsoft RDP, TeamViewer, etc.
- Automatic backups of configuration

### Development Tools

**Git** (`.gitconfig`):
- User: Yuan Liu (lyncredible@outlook.com)
- Rerere enabled (remembers merge resolutions)
- Pull with rebase strategy
- Push to current branch by default
- Disabled pager for branch/config commands

**Vim** (`.vimrc`):
- Minimal configuration
- Filetype plugins and syntax highlighting

**Tmux** (`.tmux.conf`):
- Mouse support enabled
- 50,000 line history
- Custom split keybindings: Shift+| and Shift+\ (horizontal), - (vertical)

## Patterns & Conventions

### Multi-Platform Support

**Strategy:**
- Detect environment and adapt behavior
- Platform-specific tools (Hammerspoon/AutoHotkey)
- Conditional initialization in shell configs

**Editor Detection:**
```zsh
# SSH sessions: vim
# WSL: wslsubl -n -w (with Windows path conversion)
# macOS/Linux: subl -n -w
```

### Non-Destructive Linking

**Approach:**
- `.zshrc` is a **sourcing wrapper**, not a symlink
- Sources both `~/.dotfiles/main.zshrc` AND `~/.zshrc_local`
- Allows local customizations without modifying repository
- All other configs use symlinks for easy updates

**Example `.zshrc` structure:**
```zsh
source ~/.dotfiles/main.zshrc
[[ -f ~/.zshrc_local ]] && source ~/.zshrc_local
```

### Auto-Update Mechanism

**How it Works:**
1. Every 24 hours (tracked via `~/.dotfiles_last_update`)
2. Runs `git fetch && git rebase origin/master`
3. On success, triggers `antigen update`
4. Recompiles zsh config to `.zshrc.zwc` for performance

**Implementation:**
- `check_up_to_date()` in `common.sh` checks timestamp
- `.zshrc` handles git pull and plugin updates
- Silent failure with warnings if update fails

### Local Override Pattern

**Files:**
- `~/.zshrc_local` - Local shell customizations
- Platform-specific checks in `main.zshrc`
- Git config includes for machine-specific settings

**Example Use Cases:**
- Work-specific aliases
- Company VPN configurations
- Machine-specific PATH adjustments

## Setup & Installation

### Initial Installation (`install.sh`)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.sh)"
```

**What it Does:**
1. Checks for prerequisites (zsh, git)
2. Clones repository to `~/.dotfiles`
3. Supports HTTPS (default) or SSH mode
4. Calls `setup.sh` automatically
5. Color-coded terminal output

### Environment Configuration (`setup.sh`)

**Actions:**
1. Creates `~/.zshrc` sourcing wrapper
2. Creates symlinks:
   - `~/.p10k.zsh` → Powerlevel10k config
   - `~/.vimrc` → Vim config
   - `~/.tmux.conf` → Tmux config
   - `~/.hammerspoon` → Hammerspoon directory
   - `~/.config/karabiner` → Karabiner config
   - `~/.config/ghostty` → Ghostty config
3. Installs Antigen if not present
4. Sets zsh as default shell (if needed)
5. Adds git config include path
6. Creates `~/.config` directory if missing

### Post-Setup

**Manual Steps:**
- Install Powerlevel10k fonts (MesloLGM Nerd Font)
- Install Hammerspoon (macOS)
- Install Karabiner-Elements (macOS)
- Install Ghostty or iTerm2 (macOS)
- Install AutoHotkey v2.0 (Windows)

## Important Files Reference

| File | Purpose | Notes |
|------|---------|-------|
| `main.zshrc` | Primary shell config | Sources plugins, sets up PATH |
| `.zshrc` | Entry point | Wrapper that sources main + local |
| `.p10k.zsh` | Prompt theme | Two-line, rainbow, instant prompt |
| `.hammerspoon/init.lua` | Window management | macOS automation and hotkeys |
| `init.ahk` | Window management | Windows automation (AHK v2) |
| `karabiner/karabiner.json` | Keyboard remapping | RDP key swap, Opt↔Cmd |
| `ghostty/config` | Terminal config | Modern terminal emulator |
| `.gitconfig` | Git global settings | Rerere, rebase, user info |
| `.aliases` | Shell shortcuts | Python venv, git shortcuts |
| `setup.sh` | Installation script | Creates symlinks, installs plugins |
| `common.sh` | Utility functions | Update checks, timestamps |

## Development Environment Support

### Node.js
- **NVM** (Node Version Manager)
- Loads in `main.zshrc` if installed
- `~/.nvm/nvm.sh` sourced automatically

### Ruby
- **rbenv** (Ruby environment manager)
- Initializes in `main.zshrc`
- `rbenv init` if available

### Go
- **GOPATH** set to `~/go`
- Adds `~/go/bin` to PATH

### Python
- **uv** tool expected
- Warning shown if not installed
- Python venv shortcuts in `.aliases`:
  - `venv` - Create venv
  - `act` - Activate venv
  - `dact` - Deactivate venv

### Homebrew (macOS/Linux)
- Analytics disabled
- Added to PATH if installed

## Common Tasks

### Adding New Dotfiles

1. Add the file to `~/.dotfiles/`
2. Edit `setup.sh` to create symlink:
   ```bash
   ln -sf ~/.dotfiles/.myconfig ~/.myconfig
   ```
3. Run `setup.sh` to apply changes
4. Commit and push to repository

### Adding Shell Aliases or Functions

**For Personal Use:**
1. Edit `~/.zshrc_local` (not tracked by git)
2. Add aliases/functions there
3. Reload: `source ~/.zshrc`

**For Repository:**
1. Edit `~/.dotfiles/.aliases` or `~/.dotfiles/main.zshrc`
2. Commit changes
3. Changes auto-apply on next shell startup

### Modifying Window Management Shortcuts

**macOS (Hammerspoon):**
1. Edit `.hammerspoon/init.lua`
2. Modify or add keybindings
3. Reload: Cmd+Ctrl+R (auto-reload configured)

**Windows (AutoHotkey):**
1. Edit `init.ahk`
2. Right-click AHK tray icon → Reload Script

### Updating Configurations

**Manual Update:**
```bash
cd ~/.dotfiles
git pull --rebase origin master
antigen update
```

**Automatic:**
- Runs every 24 hours automatically
- No action needed

## Gotchas & Notes

### Critical Behaviors

1. **`.zshrc` is NOT a symlink**
   - It's a sourcing wrapper created by `setup.sh`
   - Allows local overrides via `~/.zshrc_local`
   - Do not replace it with a symlink

2. **Antigen Auto-Updates**
   - Updates automatically when dotfiles update
   - Can cause shell startup delays occasionally
   - Manual update: `antigen update`

3. **SSH Agent in Tmux**
   - Precmd hook updates `SSH_AUTH_SOCK` on each prompt
   - Essential for agent forwarding across tmux sessions
   - Located in `main.zshrc`

4. **Platform Detection**
   - Uses `uname` to detect OS
   - Editor selection based on SSH/WSL/macOS detection
   - Some features only work on specific platforms

5. **Git Remote Configuration**
   - Uses custom remote: `git@github.lync:Lyncredible/dotfiles.git`
   - `lynclone()` function supports multiple SSH keys
   - May need SSH config for `github.lync` host alias

6. **Hammerspoon Reload**
   - Cmd+Ctrl+R bound to reload configuration
   - SpoonInstall auto-reloads on config change
   - Check console for errors after reload

7. **Karabiner JSON Complexity**
   - Direct JSON editing can break configuration
   - Use Karabiner GUI when possible
   - Automatic backups saved in `automatic_backups/`

8. **Terminal Font Requirements**
   - Powerlevel10k requires Nerd Fonts
   - Install MesloLGM Nerd Font for proper rendering
   - Unicode/icons will break without proper fonts

9. **Ultra-wide Monitor Detection**
   - Hammerspoon detects aspect ratio
   - Adapts window layouts for 21:9+ displays
   - May need manual adjustment for unusual resolutions

10. **WSL Path Conversion**
    - `wslsubl` script converts WSL paths to Windows paths
    - Required for WSL → Windows GUI integration
    - Uses `wslpath` utility

## Best Practices for AI Agents

### When Modifying Configurations

1. **Always preserve existing patterns**
   - Match the style and conventions in existing files
   - Don't introduce new plugin managers or tools without discussion

2. **Test on the target platform**
   - macOS-specific: Hammerspoon, Karabiner
   - Windows-specific: AutoHotkey
   - Cross-platform: Shell configs

3. **Respect the override system**
   - Don't force changes that should be local
   - Use `~/.zshrc_local` pattern for optional features

4. **Update both platforms**
   - If changing window management, update both Hammerspoon AND AutoHotkey
   - Keep keybindings consistent across platforms

5. **Document significant changes**
   - Update this file (AGENTS.md) for major additions
   - Add comments in complex configuration sections

### When Troubleshooting

1. **Check platform first**
   - Is the issue macOS/Linux/Windows specific?
   - Does the feature work on the current platform?

2. **Verify dependencies**
   - Antigen installed?
   - Required fonts installed?
   - Platform-specific tools available?

3. **Check auto-update status**
   - When was last update? (`cat ~/.dotfiles_last_update`)
   - Any errors in shell initialization?

4. **Review symlinks**
   - Are all expected symlinks created? (`ls -la ~/.*`)
   - Did `setup.sh` run successfully?

---

**Repository**: `git@github.lync:Lyncredible/dotfiles.git`
**Author**: Yuan Liu (lyncredible@outlook.com)
**Last Updated**: 2026-01-17
