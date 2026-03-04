#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2329

recent_epoch() {
  local before="$1"
  local value
  value=$(cat)
  [ "$value" -ge "$before" ]
}

Describe 'check_up_to_date()'
  setup() { TEST_DIR=$(mktemp -d); }
  cleanup() { rm -rf "$TEST_DIR"; }
  Before 'setup'
  After 'cleanup'

  It 'returns 1 when file does not exist'
    When call check_up_to_date "$TEST_DIR/nonexistent"
    The status should equal 1
  End

  It 'returns 1 when timestamp is older than 24 hours'
    old_epoch=$(( $(date +'%s') - 90000 ))
    echo "$old_epoch" > "$TEST_DIR/last_update"
    When call check_up_to_date "$TEST_DIR/last_update"
    The status should equal 1
  End

  It 'returns 0 when timestamp is within 24 hours'
    date +'%s' > "$TEST_DIR/last_update"
    When call check_up_to_date "$TEST_DIR/last_update"
    The status should be success
  End
End

Describe 'write_update_timestamp()'
  setup() { TEST_DIR=$(mktemp -d); }
  cleanup() { rm -rf "$TEST_DIR"; }
  Before 'setup'
  After 'cleanup'

  It 'creates the file with a timestamp'
    When call write_update_timestamp "$TEST_DIR/last_update"
    The status should be success
    The file "$TEST_DIR/last_update" should be exist
  End

  It 'writes a recent epoch value'
    before=$(date +'%s')
    When call write_update_timestamp "$TEST_DIR/last_update"
    The contents of file "$TEST_DIR/last_update" should satisfy recent_epoch "$before"
  End
End

Describe 'merge_claude_settings()'
  setup() { TEST_DIR=$(mktemp -d); }
  cleanup() { rm -rf "$TEST_DIR"; }
  Before 'setup'
  After 'cleanup'

  It 'preserves extra keys in settings.json'
    cat > "$TEST_DIR/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
JSON
    cat > "$TEST_DIR/settings.json" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["foo"] }
JSON
    When call merge_claude_settings "$TEST_DIR/settings.json.dist" "$TEST_DIR/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_DIR/settings.json" '.enabledPlugins[0]' "foo"
  End

  It 'copies dist verbatim when settings.json is missing'
    cat > "$TEST_DIR/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
JSON
    When call merge_claude_settings "$TEST_DIR/settings.json.dist" "$TEST_DIR/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_DIR/settings.json" '.model' "claude-opus-4-6"
  End

  It 'adds new keys from dist'
    cat > "$TEST_DIR/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "newFeature": true }
JSON
    cat > "$TEST_DIR/settings.json" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["bar"] }
JSON
    When call merge_claude_settings "$TEST_DIR/settings.json.dist" "$TEST_DIR/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_DIR/settings.json" '.newFeature' "true"
  End

  It 'overrides existing values with dist values'
    cat > "$TEST_DIR/settings.json.dist" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-sonnet-4-20250514" }
JSON
    cat > "$TEST_DIR/settings.json" <<'JSON'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
JSON
    When call merge_claude_settings "$TEST_DIR/settings.json.dist" "$TEST_DIR/settings.json"
    The status should be success
    Assert json_value_should_eq "$TEST_DIR/settings.json" '.model' "claude-sonnet-4-20250514"
  End
End
