#!/usr/bin/env zsh
# Tests for merge_claude_settings() in common.sh.
# Runs 4 scenarios against a temp directory; exits non-zero on any failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

PASS=0
FAIL=0

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

assert_json_eq() {
  local label="$1" file="$2" key="$3" expected="$4"
  local actual
  actual=$(jq -r "$key" "$file")
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

reset_tmp() { rm -f "$tmpdir/settings.json" "$tmpdir/settings.json.dist"; }

# ============================================================
# Test 1: Both exist, extra keys preserved
# ============================================================
reset_tmp
cat > "$tmpdir/settings.json.dist" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
EOF
cat > "$tmpdir/settings.json" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["foo"] }
EOF
merge_claude_settings "$tmpdir/settings.json.dist" "$tmpdir/settings.json"
assert_json_eq "extra keys preserved after merge" \
  "$tmpdir/settings.json" '.enabledPlugins[0]' "foo"

# ============================================================
# Test 2: settings.json missing — dist copied verbatim
# ============================================================
reset_tmp
cat > "$tmpdir/settings.json.dist" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
EOF
merge_claude_settings "$tmpdir/settings.json.dist" "$tmpdir/settings.json"
assert_json_eq "missing settings.json copies dist" \
  "$tmpdir/settings.json" '.model' "claude-opus-4-6"

# ============================================================
# Test 3: dist adds new key
# ============================================================
reset_tmp
cat > "$tmpdir/settings.json.dist" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "newFeature": true }
EOF
cat > "$tmpdir/settings.json" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6", "enabledPlugins": ["bar"] }
EOF
merge_claude_settings "$tmpdir/settings.json.dist" "$tmpdir/settings.json"
assert_json_eq "dist new key appears in merged result" \
  "$tmpdir/settings.json" '.newFeature' "true"

# ============================================================
# Test 4: dist overrides existing value
# ============================================================
reset_tmp
cat > "$tmpdir/settings.json.dist" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-sonnet-4-20250514" }
EOF
cat > "$tmpdir/settings.json" <<'EOF'
{ "attribution": { "commit": "", "pr": "" }, "model": "claude-opus-4-6" }
EOF
merge_claude_settings "$tmpdir/settings.json.dist" "$tmpdir/settings.json"
assert_json_eq "dist overrides existing value" \
  "$tmpdir/settings.json" '.model' "claude-sonnet-4-20250514"

# ============================================================
# Summary
# ============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
