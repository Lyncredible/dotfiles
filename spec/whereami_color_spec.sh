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
End
