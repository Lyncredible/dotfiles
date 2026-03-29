#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
  make_stub hostname <<'STUB'
#!/bin/sh
echo "myhost.example.com"
STUB
  PATH="$TEST_BIN:/bin:/usr/bin"
  export PATH
}

cleanup() {
  cleanup_test_root
}

load_whereami() {
  WHEREAMI_SOURCE_ONLY=1 . "$SHELLSPEC_PROJECT_ROOT/.local/bin/whereami"
}

Describe 'get_short_hostname()'
  Before 'setup'
  After 'cleanup'

  It 'returns first segment of dotted hostname'
    load_whereami
    When call get_short_hostname
    The status should be success
    The output should equal 'myhost'
  End
End

Describe 'string_to_index()'
  Before 'setup'
  After 'cleanup'

  It 'returns deterministic value for same input'
    load_whereami
    When call string_to_index "test-host" 75
    The status should be success
    The output should not equal ''
  End

  It 'returns same value on repeated calls'
    load_whereami
    result1=$(string_to_index "test-host" 75)
    When call string_to_index "test-host" 75
    The output should equal "$result1"
  End

  It 'returns value within mod range'
    load_whereami
    in_range_0_75() { [ "$1" -ge 0 ] && [ "$1" -lt 75 ]; }
    When call string_to_index "test-host" 75
    The status should be success
    The output should satisfy in_range_0_75
  End
End

Describe 'get_emoji()'
  Before 'setup'
  After 'cleanup'

  It 'returns an emoji for index 0'
    load_whereami
    When call get_emoji 0
    The status should be success
    The output should not equal ''
  End

  It 'returns an emoji for last index (74)'
    load_whereami
    When call get_emoji 74
    The status should be success
    The output should not equal ''
  End
End

Describe 'get_identifier()'
  Before 'setup'
  After 'cleanup'

  It 'falls back to hostname when whereami-resolve is absent'
    load_whereami
    When call get_identifier
    The status should be success
    The output should equal 'myhost'
  End

  It 'uses whereami-resolve when present'
    make_stub whereami-resolve <<'STUB'
#!/bin/sh
echo "my-devbox"
STUB
    load_whereami
    When call get_identifier
    The status should be success
    The output should equal 'my-devbox'
  End
End

Describe 'get_custom_emoji()'
  Before 'setup'
  After 'cleanup'

  It 'returns empty when whereami-resolve is absent'
    load_whereami
    When call get_custom_emoji
    The status should be success
    The output should equal ''
  End

  It 'returns emoji from whereami-resolve when present'
    make_stub whereami-resolve <<'STUB'
#!/bin/sh
if [ "$1" = "--emoji" ]; then
  echo "rocket"
fi
STUB
    load_whereami
    When call get_custom_emoji
    The status should be success
    The output should equal 'rocket'
  End
End

Describe 'main()'
  Before 'setup'
  After 'cleanup'

  It 'outputs identifier followed by emoji'
    load_whereami
    When call main
    The status should be success
    The output should include 'myhost'
  End

  It 'outputs name only with -n flag'
    load_whereami
    When call main -n
    The status should be success
    The output should equal 'myhost'
  End

  It 'formats Codespaces output when CODESPACES=true'
    load_whereami
    CODESPACES=true
    GITHUB_REPOSITORY="org/my-repo"
    CODESPACE_NAME="my-codespace-abc123"
    export CODESPACES GITHUB_REPOSITORY CODESPACE_NAME
    When call main
    The status should be success
    The output should include 'my-repo'
    The output should include 'my-codespace'
  End
End
