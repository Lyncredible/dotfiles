#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
}

cleanup() {
  cleanup_test_root
}

load_whereami_color() {
  WHEREAMI_COLOR_SOURCE_ONLY=1 \
    . "$SHELLSPEC_PROJECT_ROOT/.local/bin/whereami-color"
}

Describe 'string_to_hue()'
  Before 'setup'
  After 'cleanup'

  It 'returns deterministic value for same input'
    load_whereami_color
    result1=$(string_to_hue "test-host")
    When call string_to_hue "test-host"
    The output should equal "$result1"
  End

  It 'returns value in 0-359 range'
    load_whereami_color
    in_range_0_360() { [ "$1" -ge 0 ] && [ "$1" -lt 360 ]; }
    When call string_to_hue "test-host"
    The status should be success
    The output should satisfy in_range_0_360
  End
End

Describe 'hsl_to_hex()'
  Before 'setup'
  After 'cleanup'

  It 'returns valid 6-char hex for red hue'
    load_whereami_color
    When call hsl_to_hex 0 60 25
    The status should be success
    The output should match pattern '??????'
  End

  It 'returns valid 6-char hex for blue hue'
    load_whereami_color
    When call hsl_to_hex 240 60 25
    The status should be success
    The output should match pattern '??????'
  End
End

Describe 'color_main()'
  Before 'setup'
  After 'cleanup'

  It 'outputs bg color by default'
    load_whereami_color
    WHEREAMI_BIN=/nonexistent
    export WHEREAMI_BIN
    When call color_main
    The status should be success
    The output should match pattern '??????'
  End

  It 'outputs fg color with fg arg'
    load_whereami_color
    WHEREAMI_BIN=/nonexistent
    export WHEREAMI_BIN
    When call color_main fg
    The status should be success
    The output should match pattern '??????'
  End

  It 'outputs both colors with both arg'
    load_whereami_color
    WHEREAMI_BIN=/nonexistent
    export WHEREAMI_BIN
    When call color_main both
    The status should be success
    The output should include 'bg='
    The output should include 'fg='
  End

  It 'uses theme cyan locally when no SSH vars set'
    load_whereami_color
    unset SSH_TTY SSH_CONNECTION WHEREAMI_COLOR_HUE
    local_bg=$(color_main bg)
    # Same input should produce same output
    When call color_main bg
    The output should equal "$local_bg"
  End

  It 'uses hash-based color over SSH'
    load_whereami_color
    unset WHEREAMI_COLOR_HUE
    WHEREAMI_BIN=/nonexistent
    SSH_TTY=/dev/pts/0
    SSH_CONNECTION=
    export WHEREAMI_BIN SSH_TTY SSH_CONNECTION
    ssh_bg=$(color_main bg)
    # Local (no SSH) should differ from SSH
    unset SSH_TTY SSH_CONNECTION
    When call color_main bg
    The output should not equal "$ssh_bg"
  End

  It 'WHEREAMI_COLOR_HUE overrides both local and SSH'
    load_whereami_color
    WHEREAMI_COLOR_HUE=120
    export WHEREAMI_COLOR_HUE
    override_bg=$(color_main bg)
    # Same with SSH set — override still wins
    SSH_TTY=/dev/pts/0
    export SSH_TTY
    When call color_main bg
    The output should equal "$override_bg"
  End

  It 'outputs 256-color index with --256 flag'
    load_whereami_color
    unset SSH_TTY SSH_CONNECTION WHEREAMI_COLOR_HUE
    When call color_main --256 bg
    The status should be success
    The output should match pattern '[0-9]*'
  End
End
