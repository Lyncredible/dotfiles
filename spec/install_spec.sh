#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  TEST_BIN="$TEST_HOME/bin"
  mkdir -p "$TEST_HOME/.dotfiles" "$TEST_BIN"

  TEST_DOTFILES_DIR="$TEST_HOME/.dotfiles"
  TEST_SHELLS_FILE="$TEST_HOME/shells"
  TEST_GIT_BIN="git"
  TEST_GREP_BIN="grep"
  TEST_SETUP_SCRIPT="$TEST_DOTFILES_DIR/setup.sh"
  TEST_PATH="$TEST_BIN:/usr/bin:/bin"
  TEST_SHELL="/bin/bash"
  unset MOCK_GIT_CLONE_FAIL

  cat > "$TEST_SHELLS_FILE" <<'EOF'
/bin/bash
/bin/zsh
EOF

  cat > "$TEST_HOME/shells-no-zsh" <<'EOF'
/bin/bash
EOF

  cat > "$TEST_DOTFILES_DIR/setup.sh" <<'EOF'
#!/bin/sh
echo setup-ran >> "$HOME/.install_calls"
EOF
  chmod +x "$TEST_DOTFILES_DIR/setup.sh"

  cat > "$TEST_BIN/grep" <<'EOF'
#!/bin/sh
exec /usr/bin/grep "$@"
EOF
  chmod +x "$TEST_BIN/grep"

  cat > "$TEST_BIN/git" <<'EOF'
#!/bin/sh
echo "$*" >> "$HOME/.install_calls"
if [ "$1" = "clone" ] && [ "$MOCK_GIT_CLONE_FAIL" = "1" ]; then
  exit 1
fi
exit 0
EOF
  chmod +x "$TEST_BIN/git"
}

cleanup() {
  rm -rf "$TEST_DIR"
}

run_install() {
  HOME="$TEST_HOME" \
  PATH="$TEST_PATH" \
  SHELL="$TEST_SHELL" \
  DOTFILES_DIR="$TEST_DOTFILES_DIR" \
  SHELLS_FILE="$TEST_SHELLS_FILE" \
  SETUP_SCRIPT="$TEST_SETUP_SCRIPT" \
  GIT_BIN="$TEST_GIT_BIN" \
  GREP_BIN="$TEST_GREP_BIN" \
    /bin/sh "$SHELLSPEC_PROJECT_ROOT/install.sh" "$@"
}

Describe 'install.sh'
  Before 'setup'
  After 'cleanup'

  It 'clones over HTTPS by default and invokes setup'
    When run run_install
    The status should be success
    The contents of file "$TEST_HOME/.install_calls" \
      should include "clone https://github.com/Lyncredible/dotfiles.git $TEST_DOTFILES_DIR"
    The contents of file "$TEST_HOME/.install_calls" should include 'setup-ran'
  End

  It 'clones over SSH with -s'
    When run run_install -s
    The status should be success
    The contents of file "$TEST_HOME/.install_calls" \
      should include "clone git@github.com:Lyncredible/dotfiles.git $TEST_DOTFILES_DIR"
  End

  It 'fails when zsh is not listed in SHELLS_FILE'
    TEST_SHELLS_FILE="$TEST_HOME/shells-no-zsh"
    When run run_install
    The status should be failure
    The output should include 'Zsh is not installed'
  End

  It 'fails when configured git binary is missing'
    TEST_GIT_BIN="missing-git"
    When run run_install
    The status should be failure
    The output should include 'Error: git is not installed'
  End

  It 'fails when clone fails and does not invoke setup'
    MOCK_GIT_CLONE_FAIL=1
    export MOCK_GIT_CLONE_FAIL
    When run run_install
    The status should be failure
    The output should include 'Failed to clone dotfiles repo.'
    The file "$TEST_HOME/.install_calls" should be exist
    The contents of file "$TEST_HOME/.install_calls" should not include 'setup-ran'
  End

  It 'uses DOTFILES_DIR override as clone target'
    TEST_DOTFILES_DIR="$TEST_HOME/custom-dotfiles"
    TEST_SETUP_SCRIPT="$TEST_HOME/custom-dotfiles/setup.sh"
    mkdir -p "$TEST_DOTFILES_DIR"
    cat > "$TEST_SETUP_SCRIPT" <<'EOF'
#!/bin/sh
echo custom-setup-ran >> "$HOME/.install_calls"
EOF
    chmod +x "$TEST_SETUP_SCRIPT"
    When run run_install
    The status should be success
    The contents of file "$TEST_HOME/.install_calls" \
      should include "clone https://github.com/Lyncredible/dotfiles.git $TEST_DOTFILES_DIR"
    The contents of file "$TEST_HOME/.install_calls" should include 'custom-setup-ran'
  End

  It 'fails when SETUP_SCRIPT returns non-zero'
    cat > "$TEST_HOME/fail-setup.sh" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$TEST_HOME/fail-setup.sh"
    TEST_SETUP_SCRIPT="$TEST_HOME/fail-setup.sh"
    When run run_install
    The status should be failure
    The output should include 'Failed to run setup script.'
  End
End
