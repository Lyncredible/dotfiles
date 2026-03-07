#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

symlink_to() {
  local path="$1"
  local target="$2"
  [ -L "$path" ] && [ "$(/usr/bin/readlink "$path")" = "$target" ]
}

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  TEST_BIN="$TEST_HOME/bin"
  TEST_PATH="$TEST_BIN:/usr/bin:/bin"
  mkdir -p "$TEST_HOME/.dotfiles" "$TEST_BIN"

  cat > "$TEST_BIN/git" <<'EOF'
#!/bin/sh
echo "$*" >> "$HOME/.setup_calls"
if [ "$1" = "config" ] && [ "$2" = "--global" ] && \
  [ "$3" = "--get-all" ] && [ "$4" = "include.path" ]; then
  if [ "$MOCK_INCLUDE_PRESENT" = "1" ]; then
    echo "$HOME/.dotfiles/.gitconfig"
  fi
  exit 0
fi
exit 0
EOF
  chmod +x "$TEST_BIN/git"

  cat > "$TEST_BIN/which" <<'EOF'
#!/bin/sh
if [ "$1" = "zsh" ]; then
  echo /usr/bin/zsh
  exit 0
fi
exec /usr/bin/which "$@"
EOF
  chmod +x "$TEST_BIN/which"

  cat > "$TEST_BIN/chsh" <<'EOF'
#!/bin/sh
echo "chsh:$*" >> "$HOME/.setup_calls"
exit 0
EOF
  chmod +x "$TEST_BIN/chsh"
}

cleanup() {
  rm -rf "$TEST_DIR"
}

run_setup() {
  HOME="$TEST_HOME" PATH="$TEST_PATH" SHELL=/bin/bash \
    sh "$SHELLSPEC_PROJECT_ROOT/setup.sh"
}

Describe 'setup.sh'
  Before 'setup'
  After 'cleanup'

  It 'creates wrapper files, links, antigen clone, and chsh'
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    The contents of file "$TEST_HOME/.zshrc" should include 'source ~/.dotfiles/.zshrc'
    The contents of file "$TEST_HOME/.zshrc" should include 'source ~/.zshrc_local'
    The file "$TEST_HOME/.zshrc_local" should be exist
    Assert symlink_to "$TEST_HOME/.p10k.zsh" "$TEST_HOME/.dotfiles/.p10k.zsh"
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_HOME/.dotfiles/.vimrc"
    Assert symlink_to "$TEST_HOME/.tmux.conf" "$TEST_HOME/.dotfiles/.tmux.conf"
    Assert symlink_to "$TEST_HOME/.hammerspoon" "$TEST_HOME/.dotfiles/.hammerspoon"
    Assert symlink_to "$TEST_HOME/.claude" "$TEST_HOME/.dotfiles/.claude"
    The directory "$TEST_HOME/.config" should be exist
    Assert symlink_to "$TEST_HOME/.config/karabiner" "$TEST_HOME/.dotfiles/karabiner"
    Assert symlink_to "$TEST_HOME/.config/ghostty" "$TEST_HOME/.dotfiles/ghostty"
    The contents of file "$TEST_HOME/.setup_calls" \
      should include 'clone https://github.com/zsh-users/antigen.git'
    The contents of file "$TEST_HOME/.setup_calls" should include 'chsh:-s /usr/bin/zsh'
  End

  It 'does not add git include.path when already present'
    mkdir -p "$TEST_HOME/.antigen"
    MOCK_INCLUDE_PRESENT=1
    export MOCK_INCLUDE_PRESENT
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'config --global include.path'
  End

  It 'skips antigen clone when antigen directory exists'
    mkdir -p "$TEST_HOME/.antigen"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'clone https://github.com/zsh-users/antigen.git'
  End

  It 'skips chsh when shell is already zsh'
    mkdir -p "$TEST_HOME/.antigen"
    run_setup_zsh() {
      HOME="$TEST_HOME" PATH="$TEST_PATH" SHELL=/usr/bin/zsh \
        sh "$SHELLSPEC_PROJECT_ROOT/setup.sh"
    }
    When run run_setup_zsh
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" should not include 'chsh:-s /usr/bin/zsh'
  End

  It 'does not replace an existing .vimrc file'
    mkdir -p "$TEST_HOME/.antigen"
    echo local-vimrc > "$TEST_HOME/.vimrc"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.vimrc" should equal 'local-vimrc'
  End
End
