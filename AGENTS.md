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
  (tracked via `~/.dotfiles-update`).
- Runs `git fetch && git rebase origin/master`.
- On success, triggers `antigen selfupdate && antigen update`.
- On failure it warns, aborts a failed rebase, and retries an hour later.

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
- PowerShell 7 (`pwsh`) only. `install.ps1` is the exception: a fresh machine only has Windows
  PowerShell 5.1, so it installs git and pwsh, clones, then runs `setup.ps1` with pwsh. Keep
  `install.ps1` ASCII with 5.1 syntax; a Pester test parses it in `powershell.exe`.
- The pwsh `$PROFILE` is a **sourcing wrapper** written by `setup.ps1`: `~/.pwsh_pre.ps1`,
  then `powershell/profile.ps1`, then `~/.pwsh_post.ps1`. A profile it did not write is moved
  to `.bak` first. It removes the Windows PowerShell 5.1 wrapper earlier versions wrote.
- Modules install with PSResourceGet using `-Repository PSGallery`: the Microsoft Artifact
  Registry outranks PSGallery and answers Not Found.
- `powershell/p10k.omp.json` is the oh-my-posh port of `.p10k.zsh`. It uses palette color
  indexes, not hex, so it follows the terminal theme like p10k does. Keep the two in sync.
- The pwsh tab title matches the zsh one at the prompt (`user@$WHEREAMI:~\path`).
  `Get-DotfilesWhereami` in `common.ps1` ports `.local/bin/whereami` and reads its emoji list
  from that script, so keep the hash and the `emojis=` line format in step. Unlike zsh, the
  running command isn't added; Ghostty's integration shows the command line then.
- PSReadLine colors in `profile.ps1` mirror the zsh-syntax-highlighting defaults.
- `powershell/aliases.ps1` ports `.aliases` as functions (PowerShell aliases take no
  arguments). Add new aliases to both, or list zsh-only ones in `$DotfilesZshOnlyAliases`;
  `spec/powershell/aliases.Tests.ps1` fails otherwise. It removes built-in aliases that would
  hide a function; check new names with `Get-Alias <name>`.
- It also ports the oh-my-zsh git plugin aliases in actual use (`$DotfilesGitAliases`: gst,
  gl, gco, gcm, glg), with `Get-GitMainBranch` standing in for `git_main_branch`. On Windows
  they replace the built-in `gl` (Get-Location) and `gcm` (Get-Command) aliases.
- Auto-update: the profile starts `powershell/update.ps1` in a hidden process when
  `~/.dotfiles-update-pwsh` is a day old. It takes a lock on `~/.dotfiles-update-pwsh.lock`
  (never delete it), fetches and rebases onto origin/master, reruns `setup.ps1 -SkipInstall`
  if HEAD moved, then upgrades the winget packages and modules. Set `DOTFILES_SKIP_UPDATE=1`
  to turn it off. Output goes to `~/.dotfiles-update-pwsh.log`.
- Ghostty has no per-OS config conditionals. `ghostty/config` is shared; `ghostty/macos`,
  `ghostty/linux`, and `ghostty/windows` hold per-OS settings. Shortcuts use Cmd in `macos`
  and Alt in `keys-alt`, which `linux` and `windows` include. Ghostty's config dir is a real
  directory, not a link to the repo: `setup.sh` writes `~/.config/ghostty/config.ghostty`
  (picking `macos` or `linux` from `uname -s`) and `setup.ps1` writes
  `%LOCALAPPDATA%\ghostty\config.ghostty`. Each includes `config`, the OS file, then an
  optional machine-local `config.local`. Change shortcuts in both `macos` and `keys-alt`.
- AutoHotkey (`init.ahk`) is installed with winget and run at logon from a Startup-folder
  shortcut, `init.ahk.lnk`. `setup.ps1`, including the daily `-SkipInstall` rerun, restarts
  it with `/restart` so edits to `init.ahk` take effect.
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

## Claude Code

- `~/.claude` is Claude Code's own directory (login, history, transcripts, caches). Never link
  it to the repo; older setups did, and `setup.sh` moves that state back home.
- `claude/` holds what roams: `CLAUDE.md`, `settings.json`, `agents/`, and `rules/`.
  - `~/.claude/CLAUDE.md` is a generated one-line `@import` of `claude/CLAUDE.md`.
    Machine-local instructions go below the import; setup keeps them.
  - `~/.claude/agents` and `~/.claude/rules` link to `claude/` (junctions on Windows).
  - `claude/settings.json` is merged into `~/.claude/settings.json`, which Claude Code also
    writes. Repo keys win, lists are combined, local-only keys stay. It only merges when the
    repo file changed since the last merge (copy kept in `~/.claude/.dotfiles-settings.json`),
    so `/config` changes stick until then. zsh merges at startup (`merge_claude_settings`);
    `setup.ps1` merges on Windows (`Merge-ClaudeSettings`).
- `/.claude/` is gitignored: the old link target, and this repo's project-local settings.

## Agent Skills

- Skills live in `.agents/skills/` and are installed to `~/.agents/skills`.
  `~/.claude/skills` links there on Unix. On Windows, `setup.ps1` links each skill inside
  `~/.claude/skills`, which also holds the skills Claude Code syncs from claude.ai.
- `add-lync-skill`: Add or update a skill in this repo from any working
  directory, then commit and push the intended changes.

## Tests and linting

- Unit tests use [shellspec](https://shellspec.info/) under `spec/`.
- Integration tests in `spec/integration_*.sh` are stub-driven.
- `make check` runs lint + test + integration in one command.
- GitHub Actions (`.github/workflows/ci.yml`) runs lint on Ubuntu, `make test` and
  `make test-integration` on Ubuntu and macOS, and the Pester tests on Windows under
  PowerShell 7.
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
