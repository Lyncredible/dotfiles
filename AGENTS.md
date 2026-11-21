# AGENTS.md for .dotfiles

Personal dotfiles for macOS, Linux, WSL, and Windows.
Zsh shell, Powerlevel10k, window management, terminal configs.

## Scope

- Development environment configuration only.
- Multi-platform: detect OS and adapt behavior.
- Portable scripts go in `.local/bin/` (auto-symlinked by setup.sh).

## Operating principles

- `setup.sh` must stay idempotent.
- Prefer symlink-based config over appending lines into user files.
- `.zshrc` is a **sourcing wrapper** created by `setup.sh`, not a symlink.
  Do not replace it with a symlink.
- Preserve local customizations via `~/.zshrc_pre` and `~/.zshrc_post`.
- Keep scripts as minimal POSIX `sh` with `set -e` where possible.

## Shell loading order

```
~/.zshrc (created by setup.sh):
  [[ -f ~/.zshrc_pre ]]  && source ~/.zshrc_pre   # optional local pre
  source ~/.dotfiles/.zshrc                        # common.sh + main.zshrc
  [[ -f ~/.zshrc_post ]] && source ~/.zshrc_post   # optional local post
```

- `~/.zshrc_pre`: env vars or overrides needed before plugins load.
- `~/.zshrc_post`: aliases, functions, or work-specific config.
- Neither file is tracked by this repo.

## Auto-update behavior

- `maybe_update_dotfiles()` in `.zshrc` runs every 24 hours
  (tracked via `~/.dotfiles_last_update`).
- Runs `git fetch && git rebase origin/master`.
- On success, triggers `antigen selfupdate && antigen update`.
- Silent failure with warnings if network is unavailable.

## Antigen cache locking

- `acquire_antigen_cache_lock()` / `release_antigen_cache_lock()` in
  `common.sh` prevent race conditions when multiple shells start
  simultaneously (e.g. tmux with many panes).
- Uses `zsh/system` native file locking with a persistent file beside Antigen's
  shared state (`${ADOTDIR:-$HOME/.antigen}/.dotfiles-cache.lock`).
- Never delete that lock file. The OS releases ownership when the shell exits;
  there are no PID files, age checks, or stale-lock deletion.
- Initialization and periodic Antigen updates share the lock. Manual Antigen
  commands outside this wrapper still rely on Antigen's internal locking.

## PowerShell (Windows)

- `install.ps1` / `setup.ps1` mirror `install.sh` / `setup.sh`; `setup.ps1` stays idempotent.
- Both setups add `.gitconfig` to the global git `include.path`, so every OS shares it.
  Keep it valid for Git for Windows: size values must be 2g or less.
- `$PROFILE` (both Windows PowerShell and PowerShell 7) is a **sourcing wrapper** written by
  `setup.ps1`: `~/.pwsh_pre.ps1`, then `powershell/profile.ps1`, then `~/.pwsh_post.ps1`.
  A profile it did not write is moved to `.bak` first.
- `powershell/p10k.omp.json` is the oh-my-posh port of `.p10k.zsh`. It uses palette color
  indexes, not hex, so it follows the terminal theme like p10k does. Keep the two in sync.
- PSReadLine colors in `profile.ps1` mirror the zsh-syntax-highlighting defaults.
- Auto-update: the profile starts `powershell/update.ps1` in a hidden process when
  `~/.dotfiles-update-pwsh` is a day old. It takes a lock on `~/.dotfiles-update-pwsh.lock`
  (never delete it), fetches and rebases onto origin/master, reruns `setup.ps1 -SkipInstall`
  if HEAD moved, then upgrades the winget packages and modules. Set `DOTFILES_SKIP_UPDATE=1`
  to turn it off. Output goes to `~/.dotfiles-update-pwsh.log`.
- Ghostty has no per-OS config conditionals. `ghostty/config` is shared; `ghostty/unix`
  (macOS and Linux) and `ghostty/windows` hold per-OS settings (Cmd vs Alt shortcuts, fonts,
  `command`). Ghostty's config dir is a real directory, not a link to the repo: `setup.sh`
  writes `~/.config/ghostty/config.ghostty` and `setup.ps1` writes
  `%LOCALAPPDATA%\ghostty\config.ghostty`. Each includes `config`, the OS file, then an
  optional machine-local `config.local`. Change shortcuts in both OS files.
- AutoHotkey (`init.ahk`) is installed with winget and run at logon from a Startup-folder
  shortcut, `init.ahk.lnk`. `setup.ps1`, including the daily `-SkipInstall` rerun, restarts
  it with `/restart` so edits to `init.ahk` take effect.
- Keep PowerShell files ASCII: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
- Pester 5 tests live in `spec/powershell/` (`make test-powershell`). They are not part of
  `make check`, and `setup.ps1` does not set `core.hooksPath` because Windows lacks `make`.

## Gotchas

1. **Powerlevel10k requires Nerd Fonts** (MesloLGM).
   Icons break without proper fonts installed.

2. **Git remote uses a custom SSH host alias**:
   `git@github.lync:Lyncredible/dotfiles.git`.
   Requires SSH config for `github.lync`.

3. **SSH agent in tmux**: precmd hook in `main.zshrc` updates
   `SSH_AUTH_SOCK` from tmux environment on each prompt.

4. **Window management parity**: Hammerspoon (macOS) and
   AutoHotkey (Windows) mirror each other's keybindings.
   Update both when changing window shortcuts.

5. **Editor detection**: SSH → vim, WSL → wslsubl, local → subl.
   Set in `main.zshrc`.

## Hooks

- `hooks/pre-push` runs full `make check` (lint + test + integration).
- `setup.sh` auto-configures `core.hooksPath hooks`.

## Agent Skills

- Skills live in `.agents/skills/` and are installed to `~/.agents/skills`.
- `add-lync-skill`: Add or update a skill in this repo from any working
  directory, then commit and push the intended changes.

## Tests and linting

- Unit tests use [shellspec](https://shellspec.info/) under `spec/`.
- Integration tests in `spec/integration_*.sh` are stub-driven.
- `make check` runs lint + test + integration in one command.
- GitHub Actions (`.github/workflows/ci.yml`) runs lint on Ubuntu, `make test` and
  `make test-integration` on Ubuntu and macOS, and the Pester tests on Windows under both
  Windows PowerShell 5.1 and PowerShell 7.
- `make lint`: ShellCheck, line-length (100 chars), CRLF, exec-bit.
- Pass `FILES=` to target specific files.

## Agent conventions

1. **Always add tests** for new functions and behavior changes.
   Follow existing patterns: stubs, fallback paths, edge cases.
   See `spec/main_zshrc_spec.sh` for comprehensive examples.

2. **Preserve existing patterns**. Don't introduce new plugin
   managers or tools without discussion.

3. **Respect the override system**. Don't force changes that
   should be local — use `~/.zshrc_pre`/`~/.zshrc_post`.

4. **Update both platforms** when changing window management.
   Keep Hammerspoon and AutoHotkey keybindings consistent.

5. **Max line length is 100 characters** (enforced by Makefile).
