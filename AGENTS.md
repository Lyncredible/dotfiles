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
- Uses a lock directory with PID file; stale locks are cleaned up
  based on age and PID liveness.

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

## Tests and linting

- Unit tests use [shellspec](https://shellspec.info/) under `spec/`.
- Integration tests in `spec/integration_*.sh` are stub-driven.
- `make check` runs lint + test + integration in one command.
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
