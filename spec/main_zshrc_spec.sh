#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2154,SC2317,SC2329

setup() {
  create_test_root
  ZSH_BIN=$(command -v zsh)
  TEST_PATH="$TEST_BIN:/bin:/usr/bin"
  PROC_VERSION_FILE="$TEST_HOME/proc-version"
  export PROC_VERSION_FILE
  unset SSH_CONNECTION TMUX TEST_RUN_DOTFILES_UPDATED TEST_RUN_NO_UV TERM COLORTERM

  mkdir -p "$TEST_HOME/.dotfiles/.claude" "$TEST_HOME/.antigen" "$TEST_HOME/no-fzf"

  cp "$SHELLSPEC_PROJECT_ROOT/main.zshrc" "$TEST_HOME/.dotfiles/main.zshrc"
  cp "$SHELLSPEC_PROJECT_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"

  cat > "$TEST_HOME/.dotfiles/.aliases" <<'FILE'
# test aliases
alias dotfiles_test_alias="alias works"
FILE

  cat > "$TEST_HOME/.dotfiles/.p10k.zsh" <<'FILE'
# test p10k
printf 'p10k\n' >> "$HOME/.startup_order"
FILE

  cat > "$TEST_HOME/.dotfiles/.claude/settings.json.dist" <<'JSON'
{
  "attribution": { "commit": "", "pr": "" },
  "model": "claude-opus-4-6"
}
JSON

  cat > "$TEST_HOME/.dotfiles/.claude/settings.json" <<'JSON'
{
  "attribution": { "commit": "", "pr": "" },
  "model": "claude-opus-4-6",
  "enabledPlugins": ["foo"]
}
JSON

  cat > "$TEST_HOME/.antigen/antigen.zsh" <<'FILE'
antigen() {
  printf '%s\n' "$*" >> "$HOME/.antigen_calls"
  printf 'antigen:%s\n' "$*" >> "$HOME/.startup_order"
}
FILE

  make_stub git <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/.git_calls"
if [ "$1" = "clone" ]; then
  repo=${2##*/}
  repo=${repo%.git}
  mkdir -p "$repo"
fi
exit 0
STUB

  make_stub tmux <<'STUB'
#!/bin/sh
if [ "$1" = 'show-environment' ]; then
  printf 'SSH_AUTH_SOCK=%s\n' "${MOCK_SSH_AUTH_SOCK:-/tmp/mock.sock}"
fi
STUB

  make_stub nodenv <<'STUB'
#!/bin/sh
if [ "$1" = 'init' ] && [ "$2" = '-' ]; then
  printf 'export NODENV_INIT_RAN=1\n'
fi
STUB

  make_stub rbenv <<'STUB'
#!/bin/sh
if [ "$1" = 'init' ] && [ "$2" = '-' ]; then
  printf 'export RBENV_INIT_RAN=1\n'
fi
STUB

  write_fake_grep

  make_stub hostname <<'STUB'
#!/bin/sh
echo "test-host"
STUB

  make_stub fzf <<'STUB'
#!/bin/sh
exit 0
STUB

  cat > "$TEST_HOME/.fzf.zsh" <<'FILE'
printf 'fzf-brew\n' >> "$HOME/.startup_order"
FILE

  mkdir -p "$TEST_HOME/usr-share/doc/fzf/examples"
  cat > "$TEST_HOME/usr-share/doc/fzf/examples/key-bindings.zsh" <<'FILE'
printf 'fzf-apt\n' >> "$HOME/.startup_order"
FILE

  cat > "$PROC_VERSION_FILE" <<'FILE'
Linux version
FILE
}

cleanup() {
  cleanup_test_root
}

run_main_eval() {
  HOME="$TEST_HOME" \
  PATH="$TEST_PATH" \
  DOTFILES_UPDATED="${TEST_RUN_DOTFILES_UPDATED:-0}" \
  NO_UV="${TEST_RUN_NO_UV:-true}" \
  SSH_CONNECTION="${SSH_CONNECTION:-}" \
  TMUX="${TMUX:-}" \
  TERM="${TERM:-}" \
  COLORTERM="${COLORTERM:-}" \
  PROC_VERSION_FILE="$PROC_VERSION_FILE" \
  GIT_BIN="$TEST_BIN/git" \
  GREP_BIN="$TEST_BIN/grep" \
  TMUX_BIN="$TEST_BIN/tmux" \
  FZF_APT_KEY_BINDINGS="$TEST_HOME/usr-share/doc/fzf/examples/key-bindings.zsh" \
  "$ZSH_BIN" -c "
    hash -r
    source \"\$HOME/.dotfiles/common.sh\"
    source \"\$HOME/.dotfiles/main.zshrc\"
    $1
  "
}

Describe 'main.zshrc helper behavior'
  Before 'setup'
  After 'cleanup'

  It 'sets EDITOR to vim over SSH'
    SSH_CONNECTION=1
    When run run_main_eval 'print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'vim'
  End

  It 'sets EDITOR to wslsubl when WSL is detected'
    cat > "$PROC_VERSION_FILE" <<'FILE'
Linux version Microsoft
FILE
    When run run_main_eval 'print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'wslsubl -n -w'
  End

  It 'sets EDITOR to subl by default'
    When run run_main_eval 'print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'subl -n -w'
  End

  It 'prepends the expected path entries and preserves existing PATH'
    When run run_main_eval '
      print -r -- "${path[1]}"
      print -r -- "${path[2]}"
      print -r -- "${path[3]}"
      print -r -- "${path[4]}"
      print -r -- "${path[5]}"
      print -r -- "${path[6]}"
      print -r -- "${(j:\n:)path}"
    '
    The status should be success
    The output should include "$(printf '%s\n' \
      "$TEST_HOME/bin" \
      "$TEST_HOME/.dotfiles/bin" \
      "$TEST_HOME/.local/bin" \
      '/usr/local/bin' \
      '/usr/local/sbin' \
      '/opt/homebrew/bin')"
    The output should include '/bin'
    The output should include '/usr/bin'
  End

  It 'runs nodenv init only when ~/.nodenv exists'
    mkdir -p "$TEST_HOME/.nodenv"
    When run run_main_eval 'print -r -- "${NODENV_INIT_RAN:-unset}"'
    The status should be success
    The output should equal '1'
  End

  It 'does not run nodenv init when ~/.nodenv is absent'
    When run run_main_eval 'print -r -- "${NODENV_INIT_RAN:-unset}"'
    The status should be success
    The output should equal 'unset'
  End

  It 'sets GOPATH and appends GOPATH/bin to PATH'
    When run run_main_eval '
      print -r -- "$GOPATH"
      print -r -- "${path[-1]}"
    '
    The status should be success
    The output should equal "$(printf '%s\n' \
      "$TEST_HOME/go" \
      "$TEST_HOME/go/bin")"
  End

  It 'runs rbenv init only when ~/.rbenv exists'
    mkdir -p "$TEST_HOME/.rbenv"
    When run run_main_eval 'print -r -- "${RBENV_INIT_RAN:-unset}"'
    The status should be success
    The output should equal '1'
  End

  It 'does not run rbenv init when ~/.rbenv is absent'
    When run run_main_eval 'print -r -- "${RBENV_INIT_RAN:-unset}"'
    The status should be success
    The output should equal 'unset'
  End

  It 'sets Homebrew environment variables'
    When run run_main_eval '
      print -r -- "$HOMEBREW_NO_ANALYTICS"
      print -r -- "$HOMEBREW_NO_ENV_HINTS"
    '
    The status should be success
    The output should equal "$(printf '1\n1')"
  End

  It 'exports COLORTERM=truecolor for Ghostty SSH sessions when unset'
    SSH_CONNECTION=1
    TERM=xterm-ghostty
    When run run_main_eval 'print -r -- "${COLORTERM:-unset}"'
    The status should be success
    The output should equal 'truecolor'
  End

  It 'preserves existing COLORTERM for Ghostty SSH sessions'
    SSH_CONNECTION=1
    TERM=xterm-ghostty
    COLORTERM=24bit
    When run run_main_eval 'print -r -- "${COLORTERM:-unset}"'
    The status should be success
    The output should equal '24bit'
  End

  It 'does not export COLORTERM outside SSH'
    TERM=xterm-ghostty
    When run run_main_eval 'print -r -- "${COLORTERM:-unset}"'
    The status should be success
    The output should equal 'unset'
  End

  It 'does not export COLORTERM for non-Ghostty SSH sessions'
    SSH_CONNECTION=1
    TERM=xterm-256color
    When run run_main_eval 'print -r -- "${COLORTERM:-unset}"'
    The status should be success
    The output should equal 'unset'
  End

  It 'creates Claude settings from dist when settings.json is missing'
    rm -f "$TEST_HOME/.dotfiles/.claude/settings.json"
    When run run_main_eval 'test -f "$HOME/.dotfiles/.claude/settings.json" && print ok'
    The status should be success
    The output should include 'ok'
    Assert json_value_should_eq \
      "$TEST_HOME/.dotfiles/.claude/settings.json" \
      '.model' \
      'claude-opus-4-6'
  End

  It 'runs antigen update commands when DOTFILES_UPDATED=1'
    TEST_RUN_DOTFILES_UPDATED=1
    When run run_main_eval 'true'
    The status should be success
    The output should include 'Updating antigen...'
    The contents of file "$TEST_HOME/.antigen_calls" should include 'selfupdate'
    The contents of file "$TEST_HOME/.antigen_calls" should include 'update'
  End

  It 'does not run antigen update commands when DOTFILES_UPDATED=0'
    When run run_main_eval 'true'
    The status should be success
    The contents of file "$TEST_HOME/.antigen_calls" should not include 'selfupdate'
    The contents of file "$TEST_HOME/.antigen_calls" should not include 'update'
  End

  It 'registers _update_ssh_agent in precmd_functions when TMUX is set'
    TMUX=1
    When run run_main_eval 'print -r -- "${precmd_functions[*]}"'
    The status should be success
    The output should include '_update_ssh_agent'
  End

  It 'updates SSH_AUTH_SOCK from tmux environment'
    TMUX=1
    When run run_main_eval '_update_ssh_agent; print -r -- "$SSH_AUTH_SOCK"'
    The status should be success
    The output should equal '/tmp/mock.sock'
  End

  It 'does not register _update_ssh_agent in precmd_functions without TMUX'
    When run run_main_eval 'print -r -- "${precmd_functions[*]}"'
    The status should be success
    The output should not include '_update_ssh_agent'
  End

  It 'rewrites GitHub host and configures local git identity in lynclone'
    When run run_main_eval '
      cd "$HOME"
      lynclone git@github.com:org/repo.git
      pwd
    '
    The status should be success
    The output should equal "$TEST_HOME/repo"
    The contents of file "$TEST_HOME/.git_calls" should include 'clone git@github.lync:org/repo.git'
    The contents of file "$TEST_HOME/.git_calls" should include 'config user.name Yuan Liu'
    The contents of file "$TEST_HOME/.git_calls" \
      should include 'config user.email lyncredible@outlook.com'
    The contents of file "$TEST_HOME/.git_calls" should include 'config commit.gpgsign false'
  End

  It 'sources aliases from ~/.dotfiles/.aliases'
    When run run_main_eval 'alias dotfiles_test_alias'
    The status should be success
    The output should include 'dotfiles_test_alias='\''alias works'\'''
  End

  It 'prints uv warning when uv is missing and NO_UV is not true'
    TEST_RUN_NO_UV=false
    When run env \
      HOME="$TEST_HOME" \
      PATH="$TEST_HOME/no-fzf" \
      DOTFILES_UPDATED=0 \
      NO_UV=false \
      PROC_VERSION_FILE="$PROC_VERSION_FILE" \
      GIT_BIN="$TEST_BIN/git" \
      GREP_BIN="$TEST_BIN/grep" \
      TMUX_BIN="$TEST_BIN/tmux" \
      MKDIR_BIN="$(command -v mkdir)" \
      SLEEP_BIN="$(command -v sleep)" \
      UV_BIN="$TEST_HOME/no-fzf/uv" \
      FZF_BIN="$TEST_HOME/no-fzf/fzf" \
      "$ZSH_BIN" -c '
        source "$HOME/.dotfiles/common.sh"
        source "$HOME/.dotfiles/main.zshrc"
      '
    The status should be success
    The output should include 'WARNING: uv is not installed'
  End

  It 'prints fzf warning when fzf is missing'
    When run env \
      HOME="$TEST_HOME" \
      PATH="$TEST_HOME/no-fzf" \
      DOTFILES_UPDATED=0 \
      NO_UV=true \
      PROC_VERSION_FILE="$PROC_VERSION_FILE" \
      GIT_BIN="$TEST_BIN/git" \
      GREP_BIN="$TEST_BIN/grep" \
      TMUX_BIN="$TEST_BIN/tmux" \
      MKDIR_BIN="$(command -v mkdir)" \
      SLEEP_BIN="$(command -v sleep)" \
      FZF_BIN="$TEST_HOME/no-fzf/fzf" \
      "$ZSH_BIN" -c '
        source "$HOME/.dotfiles/common.sh"
        source "$HOME/.dotfiles/main.zshrc"
        warn_if_fzf_missing
      '
    The status should be success
    The output should include 'WARNING: fzf is not installed'
  End

  It 'defines interactive helper functions and autosuggest clear widget'
    When run run_main_eval '
      print -r -- \
        "${+functions[pasteinit]} ${+functions[pastefinish]} ${+functions[reset-terminal]}"
      print -r -- "${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[*]}"
    '
    The status should be success
    The output should include '1 1 1'
    The output should include 'bracketed-paste'
  End

  It 'configures paste zstyles'
    When run run_main_eval '
      zstyle -L :bracketed-paste-magic | sed -n "1,2p"
    '
    The status should be success
    The output should include 'zstyle :bracketed-paste-magic paste-init pasteinit'
    The output should include 'zstyle :bracketed-paste-magic paste-finish pastefinish'
  End

  It 'registers the reset-terminal widget and keybinding'
    When run run_main_eval '
      zle -l reset-terminal
      bindkey "^Z"
    '
    The status should be success
    The output should include 'reset-terminal'
    The output should include '"^Z" reset-terminal'
  End

  It 'applies antigen before sourcing p10k config'
    When run run_main_eval '
      startup_order=$(cat "$HOME/.startup_order")
      case "$startup_order" in
        *"antigen:apply
p10k"*) print -r -- ok ;;
        *) print -r -- fail ;;
      esac
    '
    The status should be success
    The output should equal 'ok'
  End

  It 'uses fzf --zsh when available and working'
    # Setup: Create fzf stub that supports --zsh
    make_stub fzf <<'STUB'
#!/bin/sh
if [ "$1" = "--zsh" ]; then
  printf 'printf '\''fzf-modern\\n'\'' >> "$HOME/.startup_order"\n'
  exit 0
fi
exit 0
STUB

    # Remove legacy fzf files to ensure modern method is used
    rm -f "$TEST_HOME/.fzf.zsh"
    rm -rf "$TEST_HOME/usr-share"

    When run run_main_eval 'tail -n 1 "$HOME/.startup_order"'
    The status should be success
    The output should equal 'fzf-modern'
  End

  It 'falls back to ~/.fzf.zsh when fzf --zsh fails'
    # Setup: Create fzf stub that does NOT support --zsh
    make_stub fzf <<'STUB'
#!/bin/sh
if [ "$1" = "--zsh" ]; then
  exit 1
fi
exit 0
STUB

    # Remove apt file to ensure homebrew fallback is used
    rm -rf "$TEST_HOME/usr-share"

    When run run_main_eval 'tail -n 1 "$HOME/.startup_order"'
    The status should be success
    The output should equal 'fzf-brew'
  End

  It 'falls back to apt keybindings when fzf --zsh and ~/.fzf.zsh are unavailable'
    # Setup: Create fzf stub that does NOT support --zsh
    make_stub fzf <<'STUB'
#!/bin/sh
if [ "$1" = "--zsh" ]; then
  exit 1
fi
exit 0
STUB

    # Remove homebrew file to ensure apt fallback is used
    rm -f "$TEST_HOME/.fzf.zsh"

    When run run_main_eval 'tail -n 1 "$HOME/.startup_order"'
    The status should be success
    The output should equal 'fzf-apt'
  End

  It 'does not source multiple fzf configurations'
    # Setup: Create fzf stub that supports --zsh
    make_stub fzf <<'STUB'
#!/bin/sh
if [ "$1" = "--zsh" ]; then
  printf 'printf '\''fzf-modern\\n'\'' >> "$HOME/.startup_order"\n'
  exit 0
fi
exit 0
STUB

    When run run_main_eval 'grep -c "^fzf-" "$HOME/.startup_order"'
    The status should be success
    The output should equal '1'
  End

  It 'silently continues when fzf is not available'
    # Setup: Remove fzf command and all config files
    rm -f "$TEST_BIN/fzf"
    rm -f "$TEST_HOME/.fzf.zsh"
    rm -rf "$TEST_HOME/usr-share"

    When run run_main_eval 'print ok'
    The status should be success
    The output should include 'ok'
  End

  It 'exports WHEREAMI variable'
    When run run_main_eval 'print -r -- "$WHEREAMI"'
    The status should be success
    The output should not equal ''
  End

  It 'uses whereami-resolve when available on PATH'
    mkdir -p "$TEST_HOME/.local/bin"
    cat > "$TEST_HOME/.local/bin/whereami" <<'SCRIPT'
#!/bin/sh
set -e
get_short_hostname() { hostname | cut -d. -f1; }
get_identifier() {
    if command -v whereami-resolve >/dev/null 2>&1; then
        result=$(whereami-resolve 2>/dev/null) && [ -n "$result" ] && echo "$result" && return
    fi
    get_short_hostname
}
get_identifier
SCRIPT
    chmod +x "$TEST_HOME/.local/bin/whereami"
    make_stub whereami-resolve <<'STUB'
#!/bin/sh
echo "test-box.qa"
STUB
    When run run_main_eval 'print -r -- "$WHEREAMI"'
    The status should be success
    The output should include 'test-box.qa'
  End

  It 'registers terminal title hooks in precmd and preexec'
    When run run_main_eval 'print -r -- "${precmd_functions[*]} ${preexec_functions[*]}"'
    The status should be success
    The output should include '_set_terminal_title_precmd'
    The output should include '_set_terminal_title_preexec'
  End

  It 'skips preexec title update inside tmux'
    TMUX=1
    When run run_main_eval '_set_terminal_title_preexec vim'
    The status should be success
    The output should equal ''
  End

  It 'disables oh-my-zsh auto title'
    When run run_main_eval 'print -r -- "$DISABLE_AUTO_TITLE"'
    The status should be success
    The output should equal 'true'
  End
End
