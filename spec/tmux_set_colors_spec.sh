#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
}

cleanup() {
  cleanup_test_root
}

run_tmux_set_colors() {
  HOME="$TEST_HOME" PATH="$TEST_BIN:/usr/bin:/bin" \
    /bin/sh "$SHELLSPEC_PROJECT_ROOT/.local/bin/tmux-set-colors"
}

Describe 'tmux-set-colors'
  Before 'setup'
  After 'cleanup'

  It 'sets status-style when both colors are available'
    make_stub whereami-color <<'STUB'
#!/bin/sh
case "$1" in
  bg) echo "1a2b3c" ;;
  fg) echo "d4e5f6" ;;
esac
STUB
    make_stub tmux <<'STUB'
#!/bin/sh
echo "$@" >> "$HOME/tmux_calls"
STUB
    expected='set -g status-style bg=#1a2b3c,fg=#d4e5f6'
    When call run_tmux_set_colors
    The status should be success
    The contents of file "${TEST_HOME}/tmux_calls" \
      should equal "$expected"
  End

  It 'skips tmux set when bg is empty'
    make_stub whereami-color <<'STUB'
#!/bin/sh
case "$1" in
  bg) echo "" ;;
  fg) echo "d4e5f6" ;;
esac
STUB
    make_stub tmux <<'STUB'
#!/bin/sh
echo "$@" >> "$HOME/tmux_calls"
STUB
    When call run_tmux_set_colors
    The status should be success
    The path "${TEST_HOME}/tmux_calls" should not be exist
  End

  It 'skips tmux set when fg is empty'
    make_stub whereami-color <<'STUB'
#!/bin/sh
case "$1" in
  bg) echo "1a2b3c" ;;
  fg) echo "" ;;
esac
STUB
    make_stub tmux <<'STUB'
#!/bin/sh
echo "$@" >> "$HOME/tmux_calls"
STUB
    When call run_tmux_set_colors
    The status should be success
    The path "${TEST_HOME}/tmux_calls" should not be exist
  End

  It 'skips tmux set when whereami-color is missing'
    make_stub tmux <<'STUB'
#!/bin/sh
echo "$@" >> "$HOME/tmux_calls"
STUB
    When call run_tmux_set_colors
    The status should be success
    The path "${TEST_HOME}/tmux_calls" should not be exist
  End
End
