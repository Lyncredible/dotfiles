#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2154,SC2317,SC2329

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  TEST_PATH="$TEST_HOME/bin:/usr/bin:/bin"
  ZSH_BIN=$(command -v zsh)
  unset \
    SSH_CONNECTION \
    MOCK_WSL \
    MOCK_SSH_AUTH_SOCK \
    TMUX \
    TEST_RUN_DOTFILES_UPDATED \
    TEST_RUN_NO_UV \
    TEST_RUN_PATH
  mkdir -p \
    "$TEST_HOME/.dotfiles/.claude" \
    "$TEST_HOME/.antigen" \
    "$TEST_HOME/bin" \
    "$TEST_HOME/bin-no-fzf"

  cp "$SHELLSPEC_PROJECT_ROOT/main.zshrc" "$TEST_HOME/.dotfiles/main.zshrc"
  cp "$SHELLSPEC_PROJECT_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"

  cat > "$TEST_HOME/.dotfiles/.aliases" <<'EOF'
# test aliases
EOF

  cat > "$TEST_HOME/.dotfiles/.p10k.zsh" <<'EOF'
# test p10k
EOF

  cat > "$TEST_HOME/.dotfiles/.claude/settings.json.dist" <<'EOF'
{
  "attribution": { "commit": "", "pr": "" },
  "model": "claude-opus-4-6"
}
EOF

  cat > "$TEST_HOME/.dotfiles/.claude/settings.json" <<'EOF'
{
  "attribution": { "commit": "", "pr": "" },
  "model": "claude-opus-4-6",
  "enabledPlugins": ["foo"]
}
EOF

  cat > "$TEST_HOME/.antigen/antigen.zsh" <<'EOF'
antigen() {
  printf '%s\n' "$*" >> "$HOME/.antigen_calls"
}
EOF

  cat > "$TEST_HOME/bin/git" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/.git_calls"
if [ "$1" = "clone" ]; then
  repo=$(printf '%s' "$2" | sed 's#.*/\([^/]*\)\.git$#\1#')
  mkdir -p "$repo"
fi
exit 0
EOF
  chmod +x "$TEST_HOME/bin/git"

  cat > "$TEST_HOME/bin/tmux" <<'EOF'
#!/bin/sh
if [ "$1" = "show-environment" ]; then
  printf 'SSH_AUTH_SOCK=%s\n' "${MOCK_SSH_AUTH_SOCK:-/tmp/mock.sock}"
fi
EOF
  chmod +x "$TEST_HOME/bin/tmux"

  cat > "$TEST_HOME/bin/grep" <<'EOF'
#!/bin/sh
if [ "$MOCK_WSL" = "1" ]; then
  exit 0
fi
exec /usr/bin/grep "$@"
EOF
  chmod +x "$TEST_HOME/bin/grep"

  cat > "$TEST_HOME/bin/fzf" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$TEST_HOME/bin/fzf"

  cat > "$TEST_HOME/bin-no-fzf/grep" <<'EOF'
#!/bin/sh
exec /usr/bin/grep "$@"
EOF
  chmod +x "$TEST_HOME/bin-no-fzf/grep"
}

cleanup() {
  rm -rf "$TEST_DIR"
}

run_main() {
  local run_path
  local run_status
  run_path="${TEST_RUN_PATH:-$TEST_PATH}"
  HOME="$TEST_HOME" \
  PATH="$run_path" \
  DOTFILES_UPDATED="${TEST_RUN_DOTFILES_UPDATED:-0}" \
  NO_UV="${TEST_RUN_NO_UV:-true}" \
  SSH_CONNECTION="${SSH_CONNECTION:-}" \
  MOCK_WSL="${MOCK_WSL:-}" \
  MOCK_SSH_AUTH_SOCK="${MOCK_SSH_AUTH_SOCK:-}" \
  TMUX="${TMUX:-}" \
  "$ZSH_BIN" -c '
    hash -r
    source "$HOME/.dotfiles/common.sh"
    source "$HOME/.dotfiles/main.zshrc"
  '
  run_status=$?
  unset \
    SSH_CONNECTION \
    MOCK_WSL \
    MOCK_SSH_AUTH_SOCK \
    TMUX \
    TEST_RUN_DOTFILES_UPDATED \
    TEST_RUN_NO_UV \
    TEST_RUN_PATH
  return "$run_status"
}

run_main_eval() {
  local run_path
  local run_status
  run_path="${TEST_RUN_PATH:-$TEST_PATH}"
  HOME="$TEST_HOME" \
  PATH="$run_path" \
  DOTFILES_UPDATED="${TEST_RUN_DOTFILES_UPDATED:-0}" \
  NO_UV="${TEST_RUN_NO_UV:-true}" \
  SSH_CONNECTION="${SSH_CONNECTION:-}" \
  MOCK_WSL="${MOCK_WSL:-}" \
  MOCK_SSH_AUTH_SOCK="${MOCK_SSH_AUTH_SOCK:-}" \
  TMUX="${TMUX:-}" \
  "$ZSH_BIN" -c "
    hash -r
    source \"\$HOME/.dotfiles/common.sh\"
    source \"\$HOME/.dotfiles/main.zshrc\"
    $1
  "
  run_status=$?
  unset \
    SSH_CONNECTION \
    MOCK_WSL \
    MOCK_SSH_AUTH_SOCK \
    TMUX \
    TEST_RUN_DOTFILES_UPDATED \
    TEST_RUN_NO_UV \
    TEST_RUN_PATH
  return "$run_status"
}

Describe 'main.zshrc startup behavior'
  Before 'setup'
  After 'cleanup'

  It 'sets EDITOR to vim over SSH'
    SSH_CONNECTION=1
    When run run_main_eval 'print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'vim'
  End

  It 'sets EDITOR to wslsubl when WSL is detected'
    MOCK_WSL=1
    When run run_main_eval 'print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'wslsubl -n -w'
  End

  It 'sets EDITOR to subl by default'
    When run run_main_eval 'print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'subl -n -w'
  End

  It 'creates Claude settings from dist when settings.json is missing'
    rm -f "$TEST_HOME/.dotfiles/.claude/settings.json"
    When run run_main
    The status should be success
    The file "$TEST_HOME/.dotfiles/.claude/settings.json" should be exist
    Assert json_value_should_eq \
      "$TEST_HOME/.dotfiles/.claude/settings.json" \
      '.model' \
      "claude-opus-4-6"
  End

  It 'runs antigen update commands when DOTFILES_UPDATED=1'
    TEST_RUN_DOTFILES_UPDATED=1
    When run run_main
    The status should be success
    The output should include 'Updating antigen...'
    The contents of file "$TEST_HOME/.antigen_calls" should include 'selfupdate'
    The contents of file "$TEST_HOME/.antigen_calls" should include 'update'
  End

  It 'does not run antigen update commands when DOTFILES_UPDATED=0'
    When run run_main
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

  It 'does not register _update_ssh_agent in precmd_functions without TMUX'
    When run run_main_eval 'print -r -- "${precmd_functions[*]}"'
    The status should be success
    The output should not include '_update_ssh_agent'
  End

  It 'updates SSH_AUTH_SOCK from tmux environment'
    MOCK_SSH_AUTH_SOCK=/tmp/from_tmux.sock
    When run run_main_eval '_update_ssh_agent; print -r -- "$SSH_AUTH_SOCK"'
    The status should be success
    The output should equal '/tmp/from_tmux.sock'
  End

  It 'rewrites GitHub host and configures local git identity in lynclone'
    When run run_main_eval '
      cd "$HOME"
      lynclone git@github.com:org/repo.git
      pwd
    '
    The status should be success
    The output should equal "$TEST_HOME/repo"
    The contents of file "$TEST_HOME/.git_calls" \
      should include 'clone git@github.lync:org/repo.git'
    The contents of file "$TEST_HOME/.git_calls" \
      should include 'config user.name Yuan Liu'
    The contents of file "$TEST_HOME/.git_calls" \
      should include 'config user.email lyncredible@outlook.com'
    The contents of file "$TEST_HOME/.git_calls" \
      should include 'config commit.gpgsign false'
  End

  It 'prints uv warning when uv is missing and NO_UV is not true'
    TEST_RUN_NO_UV=false
    TEST_RUN_PATH="$TEST_HOME/bin-no-fzf"
    When run run_main
    The status should be success
    The output should include 'WARNING: uv is not installed'
  End

  It 'prints fzf warning when fzf is missing'
    rm -f "$TEST_HOME/bin/fzf"
    When run env \
      HOME="$TEST_HOME" \
      PATH="$TEST_HOME/bin-no-fzf" \
      DOTFILES_UPDATED=0 \
      NO_UV=true \
      "$ZSH_BIN" -c '
        hash -r
        source "$HOME/.dotfiles/common.sh"
        source "$HOME/.dotfiles/main.zshrc"
      '
    The status should be success
    The output should include 'WARNING: fzf is not installed'
  End

  It 'defines interactive helper functions and autosuggest clear widget'
    When run run_main_eval '
      print -r -- "${+functions[pasteinit]}" \
        "${+functions[pastefinish]}" "${+functions[reset-terminal]}"
      print -r -- "${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[*]}"
    '
    The status should be success
    The output should include '1 1 1'
    The output should include 'bracketed-paste'
  End
End
