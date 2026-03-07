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

  TEST_DOTFILES_DIR="$TEST_HOME/.dotfiles"
  TEST_CONFIG_DIR="$TEST_HOME/.config"
  TEST_ANTIGEN_DIR="$TEST_HOME/.antigen"
  TEST_GIT_BIN="git"
  TEST_GREP_BIN="grep"
  TEST_ZSH_BIN="zsh"
  TEST_CHSH_BIN="chsh"
  TEST_SHELL="/bin/bash"
  unset MOCK_INCLUDE_PRESENT

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

  cat > "$TEST_BIN/grep" <<'EOF'
#!/bin/sh
exec /usr/bin/grep "$@"
EOF
  chmod +x "$TEST_BIN/grep"

  cat > "$TEST_BIN/chsh" <<'EOF'
#!/bin/sh
echo "chsh:$*" >> "$HOME/.setup_calls"
exit 0
EOF
  chmod +x "$TEST_BIN/chsh"

  cat > "$TEST_BIN/custom-chsh" <<'EOF'
#!/bin/sh
echo "custom-chsh:$*" >> "$HOME/.setup_calls"
exit 0
EOF
  chmod +x "$TEST_BIN/custom-chsh"

  cat > "$TEST_BIN/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$TEST_BIN/zsh"

  cat > "$TEST_BIN/my-zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$TEST_BIN/my-zsh"
}

cleanup() {
  rm -rf "$TEST_DIR"
}

run_setup() {
  HOME="$TEST_HOME" \
  PATH="$TEST_PATH" \
  SHELL="$TEST_SHELL" \
  DOTFILES_DIR="$TEST_DOTFILES_DIR" \
  CONFIG_DIR="$TEST_CONFIG_DIR" \
  ANTIGEN_DIR="$TEST_ANTIGEN_DIR" \
  GIT_BIN="$TEST_GIT_BIN" \
  GREP_BIN="$TEST_GREP_BIN" \
  ZSH_BIN="$TEST_ZSH_BIN" \
  CHSH_BIN="$TEST_CHSH_BIN" \
    /bin/sh "$SHELLSPEC_PROJECT_ROOT/setup.sh"
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
    Assert symlink_to "$TEST_HOME/.p10k.zsh" "$TEST_DOTFILES_DIR/.p10k.zsh"
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    Assert symlink_to "$TEST_HOME/.tmux.conf" "$TEST_DOTFILES_DIR/.tmux.conf"
    Assert symlink_to "$TEST_HOME/.hammerspoon" "$TEST_DOTFILES_DIR/.hammerspoon"
    Assert symlink_to "$TEST_HOME/.claude" "$TEST_DOTFILES_DIR/.claude"
    The directory "$TEST_CONFIG_DIR" should be exist
    Assert symlink_to "$TEST_CONFIG_DIR/karabiner" "$TEST_DOTFILES_DIR/karabiner"
    Assert symlink_to "$TEST_CONFIG_DIR/ghostty" "$TEST_DOTFILES_DIR/ghostty"
    The contents of file "$TEST_HOME/.setup_calls" \
      should include 'clone https://github.com/zsh-users/antigen.git'
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "chsh:-s $TEST_BIN/zsh"
  End

  It 'does not add git include.path when already present'
    mkdir -p "$TEST_ANTIGEN_DIR"
    MOCK_INCLUDE_PRESENT=1
    export MOCK_INCLUDE_PRESENT
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'config --global include.path'
  End

  It 'skips antigen clone when antigen directory exists'
    mkdir -p "$TEST_ANTIGEN_DIR"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'clone https://github.com/zsh-users/antigen.git'
  End

  It 'skips chsh when shell is already the resolved zsh path'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_SHELL="$TEST_BIN/zsh"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include "chsh:-s $TEST_BIN/zsh"
  End

  It 'does not replace an existing .vimrc file'
    mkdir -p "$TEST_ANTIGEN_DIR"
    echo local-vimrc > "$TEST_HOME/.vimrc"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.vimrc" should equal 'local-vimrc'
  End

  It 'uses DOTFILES_DIR override for links and include path'
    TEST_DOTFILES_DIR="$TEST_HOME/dotfiles-custom"
    mkdir -p "$TEST_DOTFILES_DIR"
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "config --global include.path $TEST_DOTFILES_DIR/.gitconfig"
  End

  It 'uses CONFIG_DIR override for config links'
    TEST_CONFIG_DIR="$TEST_HOME/custom-config"
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    Assert symlink_to "$TEST_CONFIG_DIR/karabiner" "$TEST_DOTFILES_DIR/karabiner"
    Assert symlink_to "$TEST_CONFIG_DIR/ghostty" "$TEST_DOTFILES_DIR/ghostty"
  End

  It 'uses ANTIGEN_DIR override for clone target'
    TEST_ANTIGEN_DIR="$TEST_HOME/antigen-custom"
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "clone https://github.com/zsh-users/antigen.git $TEST_ANTIGEN_DIR"
  End

  It 'uses CHSH_BIN and ZSH_BIN overrides'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_CHSH_BIN="custom-chsh"
    TEST_ZSH_BIN="my-zsh"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "custom-chsh:-s $TEST_BIN/my-zsh"
  End

  It 'fails when ZSH_BIN cannot be resolved'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_ZSH_BIN="missing-zsh"
    When run run_setup
    The status should be failure
    The contents of file "$TEST_HOME/.setup_calls" should not include 'chsh:-s'
  End
End
