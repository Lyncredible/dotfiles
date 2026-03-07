#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2154,SC2317,SC2329

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  ZSH_BIN=$(command -v zsh)
  mkdir -p "$TEST_HOME/.dotfiles" "$TEST_HOME/.dotfiles/.claude" "$TEST_HOME/.antigen" "$TEST_HOME/bin"

  cp "$SHELLSPEC_PROJECT_ROOT/main.zshrc" "$TEST_HOME/.dotfiles/main.zshrc"
  cp "$SHELLSPEC_PROJECT_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"

  cat > "$TEST_HOME/.dotfiles/.aliases" <<'EOF'
# test aliases
EOF

  cat > "$TEST_HOME/.dotfiles/.p10k.zsh" <<'EOF'
# test p10k
EOF

  cat > "$TEST_HOME/.dotfiles/.claude/settings.json.dist" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
EOF

  cat > "$TEST_HOME/.dotfiles/.claude/settings.json" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["foo"] }
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
}

cleanup() {
  rm -rf "$TEST_DIR"
}

run_main() {
  HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"'
}

Describe 'main.zshrc startup behavior'
  Before 'setup'
  After 'cleanup'

  It 'sets EDITOR to vim over SSH'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true SSH_CONNECTION=1 "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'vim'
  End

  It 'sets EDITOR to wslsubl when WSL is detected'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true MOCK_WSL=1 "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'wslsubl -n -w'
  End

  It 'sets EDITOR to subl by default'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; print -r -- "$EDITOR"'
    The status should be success
    The output should equal 'subl -n -w'
  End

  It 'creates Claude settings from dist when settings.json is missing'
    rm -f "$TEST_HOME/.dotfiles/.claude/settings.json"
    When run run_main
    The status should be success
    The file "$TEST_HOME/.dotfiles/.claude/settings.json" should be exist
    Assert json_value_should_eq "$TEST_HOME/.dotfiles/.claude/settings.json" '.model' "claude-opus-4-6"
  End

  It 'runs antigen update commands when DOTFILES_UPDATED=1'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=1 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"'
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
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true TMUX=1 "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; print -r -- ${precmd_functions[@]}'
    The status should be success
    The output should include '_update_ssh_agent'
  End

  It 'does not register _update_ssh_agent in precmd_functions without TMUX'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; print -r -- "${precmd_functions[*]}"'
    The status should be success
    The output should not include '_update_ssh_agent'
  End

  It 'updates SSH_AUTH_SOCK from tmux environment'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true MOCK_SSH_AUTH_SOCK=/tmp/from_tmux.sock "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; _update_ssh_agent; print -r -- "$SSH_AUTH_SOCK"'
    The status should be success
    The output should equal '/tmp/from_tmux.sock'
  End

  It 'rewrites GitHub host and configures local git identity in lynclone'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; cd "$HOME"; lynclone git@github.com:org/repo.git; pwd'
    The status should be success
    The output should equal "$TEST_HOME/repo"
    The contents of file "$TEST_HOME/.git_calls" should include 'clone git@github.lync:org/repo.git'
    The contents of file "$TEST_HOME/.git_calls" should include 'config user.name Yuan Liu'
    The contents of file "$TEST_HOME/.git_calls" should include 'config user.email lyncredible@outlook.com'
    The contents of file "$TEST_HOME/.git_calls" should include 'config commit.gpgsign false'
  End

  It 'prints uv warning when uv is missing and NO_UV is not true'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin" DOTFILES_UPDATED=0 "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"'
    The status should be success
    The output should include 'WARNING: uv is not installed'
  End

  It 'prints fzf warning when fzf is missing'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin" DOTFILES_UPDATED=0 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"'
    The status should be success
    The output should include 'WARNING: fzf is not installed'
  End

  It 'defines interactive helper functions and autosuggest clear widget'
    When run env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:/usr/bin:/bin" DOTFILES_UPDATED=0 NO_UV=true "$ZSH_BIN" -c 'source "$HOME/.dotfiles/common.sh"; source "$HOME/.dotfiles/main.zshrc"; print -r -- "${+functions[pasteinit]}" "${+functions[pastefinish]}" "${+functions[reset-terminal]}"; print -r -- "${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[*]}"'
    The status should be success
    The output should include '1 1 1'
    The output should include 'bracketed-paste'
  End
End
