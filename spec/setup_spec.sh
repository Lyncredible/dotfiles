#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
  mkdir -p "$TEST_HOME/.dotfiles"

  TEST_DOTFILES_DIR="$TEST_HOME/.dotfiles"
  TEST_CONFIG_DIR="$TEST_HOME/.config"
  TEST_ANTIGEN_DIR="$TEST_HOME/.antigen"
  TEST_PATH="$TEST_BIN:/bin:/usr/bin"
  TEST_SHELL="/bin/bash"
  unset MOCK_INCLUDE_PRESENT
  unset TEST_SKIP_CHSH

  write_fake_grep

  make_stub git <<'STUB'
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
STUB

  make_stub chsh <<'STUB'
#!/bin/sh
echo "chsh:$*" >> "$HOME/.setup_calls"
exit 0
STUB

  make_stub custom-chsh <<'STUB'
#!/bin/sh
echo "custom-chsh:$*" >> "$HOME/.setup_calls"
exit 0
STUB

  make_stub zsh <<'STUB'
#!/bin/sh
exit 0
STUB

  make_stub my-zsh <<'STUB'
#!/bin/sh
exit 0
STUB
}

cleanup() {
  cleanup_test_root
}

run_setup() {
  HOME="$TEST_HOME" \
  PATH="$TEST_PATH" \
  SHELL="$TEST_SHELL" \
  DOTFILES_DIR="$TEST_DOTFILES_DIR" \
  CONFIG_DIR="$TEST_CONFIG_DIR" \
  ANTIGEN_DIR="$TEST_ANTIGEN_DIR" \
  GIT_BIN="$TEST_BIN/git" \
  GREP_BIN="$TEST_BIN/grep" \
  ZSH_BIN="${TEST_ZSH_BIN:-$TEST_BIN/zsh}" \
  CHSH_BIN="${TEST_CHSH_BIN:-$TEST_BIN/chsh}" \
  SKIP_CHSH="${TEST_SKIP_CHSH:-}" \
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
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "-C $TEST_DOTFILES_DIR config core.hooksPath hooks"
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

  It 'skips chsh when SKIP_CHSH is set'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_SKIP_CHSH=1
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'chsh:-s'
  End

  It 'backs up and replaces a real file with the correct symlink'
    mkdir -p "$TEST_ANTIGEN_DIR"
    echo local-vimrc > "$TEST_HOME/.vimrc"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    The contents of file "$TEST_HOME/.vimrc.bak" should equal 'local-vimrc'
  End

  It 'fixes a wrong symlink'
    mkdir -p "$TEST_ANTIGEN_DIR"
    ln -s /tmp/wrong "$TEST_HOME/.vimrc"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    The file "$TEST_HOME/.vimrc.bak" should be symlink
  End

  It 'is idempotent — correct symlinks are left unchanged'
    mkdir -p "$TEST_ANTIGEN_DIR"
    # Pre-create correct symlinks
    ln -s "$TEST_DOTFILES_DIR/.vimrc" "$TEST_HOME/.vimrc"
    ln -s "$TEST_DOTFILES_DIR/.tmux.conf" "$TEST_HOME/.tmux.conf"
    ln -s "$TEST_DOTFILES_DIR/.p10k.zsh" "$TEST_HOME/.p10k.zsh"
    When run run_setup
    The status should be success
    The file "$TEST_HOME/.vimrc.bak" should not be exist
    The file "$TEST_HOME/.tmux.conf.bak" should not be exist
    The file "$TEST_HOME/.p10k.zsh.bak" should not be exist
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
    TEST_CHSH_BIN="$TEST_BIN/custom-chsh"
    TEST_ZSH_BIN="$TEST_BIN/my-zsh"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "custom-chsh:-s $TEST_BIN/my-zsh"
  End

  It 'fails when ZSH_BIN cannot be resolved'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_ZSH_BIN='missing-zsh'
    When run run_setup
    The status should be failure
    The contents of file "$TEST_HOME/.setup_calls" should not include 'chsh:-s'
  End

  It 'symlinks .local/bin scripts'
    mkdir -p "$TEST_ANTIGEN_DIR"
    mkdir -p "$TEST_DOTFILES_DIR/.local/bin"
    echo '#!/bin/sh' > "$TEST_DOTFILES_DIR/.local/bin/whereami"
    echo '#!/bin/sh' > "$TEST_DOTFILES_DIR/.local/bin/whereami-color"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.local/bin/whereami" \
      "$TEST_DOTFILES_DIR/.local/bin/whereami"
    Assert symlink_to "$TEST_HOME/.local/bin/whereami-color" \
      "$TEST_DOTFILES_DIR/.local/bin/whereami-color"
  End

  It 'fixes stale .local/bin symlinks on re-run'
    mkdir -p "$TEST_ANTIGEN_DIR"
    mkdir -p "$TEST_DOTFILES_DIR/.local/bin"
    mkdir -p "$TEST_HOME/.local/bin"
    echo '#!/bin/sh' > "$TEST_DOTFILES_DIR/.local/bin/whereami"
    ln -s /tmp/wrong "$TEST_HOME/.local/bin/whereami"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.local/bin/whereami" \
      "$TEST_DOTFILES_DIR/.local/bin/whereami"
  End
End
