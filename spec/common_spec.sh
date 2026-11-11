#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
  write_fake_date
  write_fake_stat
  DATE_BIN="$TEST_BIN/date"
  STAT_BIN="$TEST_BIN/stat"
  export DATE_BIN STAT_BIN

  ANTIGEN_DOTFILES_LOCK="$TEST_HOME/.test-antigen-lock"
  export ANTIGEN_DOTFILES_LOCK
  TEST_LOCK_ROOT="$TEST_HOME"
  export TEST_LOCK_ROOT
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

Describe 'merge_codex_settings()'
  Before 'setup'
  After 'cleanup'

  It 'copies dist when config.toml is missing'
    mkdir -p "$TEST_HOME/.dotfiles/.codex"
    cat > "$TEST_HOME/.dotfiles/.codex/config.toml.dist" <<'TOML'
plan_mode_reasoning_effort = "high"
TOML
    When call merge_codex_settings \
      "$TEST_HOME/.dotfiles/.codex/config.toml.dist" \
      "$TEST_HOME/.codex/config.toml"
    The status should be success
    The file "$TEST_HOME/.codex/config.toml" should be exist
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should equal 'plan_mode_reasoning_effort = "high"'
  End

  It 'replaces an existing root-level plan mode reasoning setting'
    mkdir -p "$TEST_HOME/.dotfiles/.codex" "$TEST_HOME/.codex"
    cat > "$TEST_HOME/.dotfiles/.codex/config.toml.dist" <<'TOML'
plan_mode_reasoning_effort = "high"
TOML
    cat > "$TEST_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
plan_mode_reasoning_effort = "medium"

[projects."/Users/yuan"]
trust_level = "trusted"
TOML
    When call merge_codex_settings \
      "$TEST_HOME/.dotfiles/.codex/config.toml.dist" \
      "$TEST_HOME/.codex/config.toml"
    The status should be success
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should include 'plan_mode_reasoning_effort = "high"'
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should not include 'plan_mode_reasoning_effort = "medium"'
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should include '[projects."/Users/yuan"]'
  End

  It 'inserts the managed key before the first table when absent'
    mkdir -p "$TEST_HOME/.dotfiles/.codex" "$TEST_HOME/.codex"
    cat > "$TEST_HOME/.dotfiles/.codex/config.toml.dist" <<'TOML'
plan_mode_reasoning_effort = "high"
TOML
    cat > "$TEST_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"

[projects."/Users/yuan"]
trust_level = "trusted"
TOML
    When call merge_codex_settings \
      "$TEST_HOME/.dotfiles/.codex/config.toml.dist" \
      "$TEST_HOME/.codex/config.toml"
    The status should be success
    The contents of file "$TEST_HOME/.codex/config.toml" should equal "$(cat <<'TOML'
model = "gpt-5.4"

plan_mode_reasoning_effort = "high"
[projects."/Users/yuan"]
trust_level = "trusted"
TOML
)"
  End

  It 'preserves similarly named keys inside TOML tables'
    mkdir -p "$TEST_HOME/.dotfiles/.codex" "$TEST_HOME/.codex"
    cat > "$TEST_HOME/.dotfiles/.codex/config.toml.dist" <<'TOML'
plan_mode_reasoning_effort = "high"
TOML
    cat > "$TEST_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"

[profiles.fast]
plan_mode_reasoning_effort = "low"
TOML
    When call merge_codex_settings \
      "$TEST_HOME/.dotfiles/.codex/config.toml.dist" \
      "$TEST_HOME/.codex/config.toml"
    The status should be success
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should include 'plan_mode_reasoning_effort = "high"'
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should include '[profiles.fast]'
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should include 'plan_mode_reasoning_effort = "low"'
  End

  It 'leaves config.toml untouched when the dist file is missing'
    mkdir -p "$TEST_HOME/.codex"
    cat > "$TEST_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5.4"
TOML
    When call merge_codex_settings \
      "$TEST_HOME/.dotfiles/.codex/config.toml.dist" \
      "$TEST_HOME/.codex/config.toml"
    The status should be success
    The contents of file "$TEST_HOME/.codex/config.toml" \
      should equal 'model = "gpt-5.4"'
  End
End

run_lock_eval() {
  COMMON_FILE="$SHELLSPEC_PROJECT_ROOT/common.sh" \
  zsh -fc 'source "$COMMON_FILE"; eval "$1"' zsh "$1"
}

Describe 'native Antigen cache lock'
  Before 'setup'
  After 'cleanup'

  It 'creates a persistent lock file and records the owning process'
    When run run_lock_eval '
      acquire_antigen_cache_lock || exit
      [[ -n $_ANTIGEN_DOTFILES_LOCK_FD ]] || exit 1
      [[ $_ANTIGEN_DOTFILES_LOCK_PID == ${sysparams[pid]} ]]
    '
    The status should be success
    The file "$ANTIGEN_DOTFILES_LOCK" should be exist
  End

  It 'creates the parent directory at a custom lock location'
    ANTIGEN_DOTFILES_LOCK="$TEST_HOME/custom/nested/cache.lock"
    When run run_lock_eval 'acquire_antigen_cache_lock'
    The status should be success
    The file "$ANTIGEN_DOTFILES_LOCK" should be exist
  End

  It 'defaults to the shared Antigen directory instead of a dotfiles checkout'
    When run run_lock_eval '
      unset ANTIGEN_DOTFILES_LOCK
      ADOTDIR="${TEST_LOCK_ROOT}/state"
      source "$COMMON_FILE"
      acquire_antigen_cache_lock
    '
    The status should be success
    The file "$TEST_HOME/state/.dotfiles-cache.lock" should be exist
  End

  It 'rejects nested acquisition without discarding the original ownership'
    When run run_lock_eval '
      acquire_antigen_cache_lock || exit
      fd=$_ANTIGEN_DOTFILES_LOCK_FD
      acquire_antigen_cache_lock && exit 1
      [[ $_ANTIGEN_DOTFILES_LOCK_FD == $fd ]] || exit 1
      release_antigen_cache_lock
    '
    The status should be success
    The stderr should include 'already held by this shell'
  End

  It 'preserves ownership when common.sh is sourced again'
    When run run_lock_eval '
      acquire_antigen_cache_lock || exit
      source "$COMMON_FILE"
      release_antigen_cache_lock
      [[ -z ${_ANTIGEN_DOTFILES_LOCK_FD:-} ]]
    '
    The status should be success
  End

  It 'leaves the lock file in place after release and supports reacquisition'
    When run run_lock_eval '
      acquire_antigen_cache_lock || exit
      release_antigen_cache_lock || exit
      [[ -f $ANTIGEN_DOTFILES_LOCK ]] || exit 1
      [[ -z ${_ANTIGEN_DOTFILES_LOCK_FD:-} ]] || exit 1
      acquire_antigen_cache_lock
    '
    The status should be success
    The file "$ANTIGEN_DOTFILES_LOCK" should be exist
  End

  It 'allows release when no lock was acquired or it was already released'
    When run run_lock_eval '
      release_antigen_cache_lock || exit
      acquire_antigen_cache_lock || exit
      release_antigen_cache_lock || exit
      release_antigen_cache_lock
    '
    The status should be success
  End

  It 'reports an unavailable module without creating a lock'
    When run run_lock_eval '
      zmodload() { return 1; }
      acquire_antigen_cache_lock
    '
    The status should equal 1
    The stderr should include 'Native file locking is unavailable'
    The path "$ANTIGEN_DOTFILES_LOCK" should not be exist
  End

  It 'reports an unsupported locking feature without creating a lock'
    When run run_lock_eval '
      zsystem() { return 1; }
      acquire_antigen_cache_lock
    '
    The status should equal 1
    The stderr should include 'Native file locking is unavailable'
    The path "$ANTIGEN_DOTFILES_LOCK" should not be exist
  End

  It 'rejects a negative timeout instead of waiting indefinitely'
    When run run_lock_eval 'ANTIGEN_LOCK_TIMEOUT=-1; acquire_antigen_cache_lock'
    The status should equal 1
    The stderr should include 'must be a nonnegative number'
    The path "$ANTIGEN_DOTFILES_LOCK" should not be exist
  End

  It 'rejects a nonnumeric timeout'
    When run run_lock_eval 'ANTIGEN_LOCK_TIMEOUT=invalid; acquire_antigen_cache_lock'
    The status should equal 1
    The stderr should include 'must be a nonnegative number'
    The path "$ANTIGEN_DOTFILES_LOCK" should not be exist
  End

  It 'fails without deleting a directory supplied as the lock path'
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    When run run_lock_eval 'acquire_antigen_cache_lock'
    The status should equal 1
    The stderr should include 'is a directory'
    The directory "$ANTIGEN_DOTFILES_LOCK" should be exist
  End
End

Describe 'wait_for_antigen_compile()'
  Before 'setup'
  After 'cleanup'

  It 'does not poll for Antigen v2.3 or newer, even with missing bytecode'
    ANTIGEN_CACHE="$TEST_HOME/init.zsh"
    echo '# fixture' > "$ANTIGEN_CACHE"
    SLEEP_BIN="$TEST_BIN/nonexistent-sleep"
    export SLEEP_BIN
    _ANTIGEN_CACHE_VERSION=v2.3.0

    When call wait_for_antigen_compile
    The status should be success
    The stderr should equal ''
  End

  It 'keeps the polling fallback for older Antigen versions'
    ANTIGEN_CACHE="$TEST_HOME/init.zsh"
    echo '# fixture' > "$ANTIGEN_CACHE"
    ANTIGEN_COMPILE_TIMEOUT=1
    _ANTIGEN_CACHE_VERSION=v2.2.3
    make_stub sleep <<'STUB'
#!/bin/sh
touch "$TEST_LOCK_ROOT/sleep-called"
STUB
    SLEEP_BIN="$TEST_BIN/sleep"
    export SLEEP_BIN

    When call wait_for_antigen_compile
    The status should be success
    The file "$TEST_HOME/sleep-called" should be exist
  End

  It 'returns 0 immediately if cache file does not exist'
    ANTIGEN_CACHE="$TEST_HOME/nonexistent-cache"
    export ANTIGEN_CACHE

    When call wait_for_antigen_compile
    The status should be success
  End

  It 'returns 0 when zwc file exists and is newer than cache'
    ANTIGEN_CACHE="$TEST_HOME/init.zsh"
    export ANTIGEN_CACHE

    # Create cache file
    echo "# cache content" > "$ANTIGEN_CACHE"
    sleep 0.2  # Ensure timestamp difference

    # Create newer zwc file
    touch "$ANTIGEN_CACHE.zwc"

    When call wait_for_antigen_compile
    The status should be success
  End

  It 'waits for zwc file to appear'
    ANTIGEN_CACHE="$TEST_HOME/init.zsh"
    export ANTIGEN_CACHE

    # Create cache file
    echo "# cache content" > "$ANTIGEN_CACHE"

    # Create zwc file after 0.3 seconds in background
    (sleep 0.3 && touch "$ANTIGEN_CACHE.zwc") &

    When call wait_for_antigen_compile
    The status should be success
  End

  It 'returns 0 on timeout (not treated as error)'
    ANTIGEN_CACHE="$TEST_HOME/init.zsh"
    ANTIGEN_COMPILE_TIMEOUT=1
    export ANTIGEN_CACHE ANTIGEN_COMPILE_TIMEOUT

    # Create cache file but no zwc file
    echo "# cache content" > "$ANTIGEN_CACHE"
    # Don't create zwc - will timeout

    When call wait_for_antigen_compile
    The status should be success
  End

  It 'respects ANTIGEN_CACHE environment variable'
    custom_cache="$TEST_HOME/custom-location/init.zsh"
    ANTIGEN_CACHE="$custom_cache"
    export ANTIGEN_CACHE

    # Cache doesn't exist - should return immediately
    When call wait_for_antigen_compile
    The status should be success
  End

  It 'detects when zwc becomes newer than cache during wait'
    ANTIGEN_CACHE="$TEST_HOME/init.zsh"
    export ANTIGEN_CACHE

    # Create cache
    echo "# cache" > "$ANTIGEN_CACHE"
    # Create old zwc (older than cache)
    touch -t 200501010000 "$ANTIGEN_CACHE.zwc"

    # Update zwc to be newer after 0.3 seconds
    (sleep 0.3 && touch "$ANTIGEN_CACHE.zwc") &

    When call wait_for_antigen_compile
    The status should be success
  End
End
