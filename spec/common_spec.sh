#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
  write_fake_date
  DATE_BIN="$TEST_BIN/date"
  export DATE_BIN
}

cleanup() {
  cleanup_test_root
}

Describe 'check_up_to_date()'
  Before 'setup'
  After 'cleanup'

  It 'returns 1 when file does not exist'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    When call check_up_to_date "$TEST_HOME/nonexistent"
    The status should equal 1
  End

  It 'returns 1 when timestamp is older than 24 hours'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/last_update"
    When call check_up_to_date "$TEST_HOME/last_update"
    The status should equal 1
  End

  It 'returns 0 when timestamp is within 24 hours'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999999000 > "$TEST_HOME/last_update"
    When call check_up_to_date "$TEST_HOME/last_update"
    The status should be success
  End
End

Describe 'write_update_timestamp()'
  Before 'setup'
  After 'cleanup'

  It 'creates the file with a timestamp'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    When call write_update_timestamp "$TEST_HOME/last_update"
    The status should be success
    The file "$TEST_HOME/last_update" should be exist
  End

  It 'writes the injected epoch value'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    When call write_update_timestamp "$TEST_HOME/last_update"
    The contents of file "$TEST_HOME/last_update" should equal '2000000000'
  End
End

Describe 'merge_claude_settings()'
  Before 'setup'
  After 'cleanup'

  It 'preserves extra keys in settings.json'
    cat > "$TEST_HOME/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
JSON
    cat > "$TEST_HOME/settings.json" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["foo"] }
JSON
    When call merge_claude_settings "$TEST_HOME/settings.json.dist" "$TEST_HOME/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_HOME/settings.json" '.enabledPlugins[0]' 'foo'
  End

  It 'copies dist verbatim when settings.json is missing'
    cat > "$TEST_HOME/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
JSON
    When call merge_claude_settings "$TEST_HOME/settings.json.dist" "$TEST_HOME/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_HOME/settings.json" '.model' 'claude-opus-4-6'
  End

  It 'adds new keys from dist'
    cat > "$TEST_HOME/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "newFeature": true }
JSON
    cat > "$TEST_HOME/settings.json" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["bar"] }
JSON
    When call merge_claude_settings "$TEST_HOME/settings.json.dist" "$TEST_HOME/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_HOME/settings.json" '.newFeature' 'true'
  End

  It 'overrides existing values with dist values'
    cat > "$TEST_HOME/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-sonnet-4-20250514" }
JSON
    cat > "$TEST_HOME/settings.json" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
JSON
    When call merge_claude_settings "$TEST_HOME/settings.json.dist" "$TEST_HOME/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_HOME/settings.json" '.model' 'claude-sonnet-4-20250514'
  End

  It 'leaves the settings file untouched when jq is unavailable'
    cat > "$TEST_HOME/settings.json.dist" <<'JSON'
{ "model": "claude-sonnet-4-20250514" }
JSON
    cat > "$TEST_HOME/settings.json" <<'JSON'
{ "model": "claude-opus-4-6" }
JSON
    JQ_BIN="$TEST_BIN/missing-jq"
    export JQ_BIN
    When call merge_claude_settings "$TEST_HOME/settings.json.dist" "$TEST_HOME/settings.json"
    The status should be success
    The contents of file "$TEST_HOME/settings.json" should equal '{ "model": "claude-opus-4-6" }'
  End
End
