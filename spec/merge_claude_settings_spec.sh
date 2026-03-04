#!/bin/sh
# shellcheck disable=SC2016

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
