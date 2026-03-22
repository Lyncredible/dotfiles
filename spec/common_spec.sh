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

Describe 'acquire_antigen_cache_lock()'
  Before 'setup'
  After 'cleanup'

  It 'acquires lock successfully on first attempt'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    When call acquire_antigen_cache_lock
    The status should be success
    The directory "$ANTIGEN_DOTFILES_LOCK" should be exist
  End

  It 'stores PID in lock directory'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    When call acquire_antigen_cache_lock
    The status should be success
    The file "$ANTIGEN_DOTFILES_LOCK/pid" should be exist
    The contents of file "$ANTIGEN_DOTFILES_LOCK/pid" should equal "$$"
  End

  It 'returns 1 when timeout is reached'
    # Lock mtime is fresh so it won't be considered stale
    FAKE_EPOCH=2000000000
    FAKE_STAT_MTIME=1999999999
    export FAKE_EPOCH FAKE_STAT_MTIME
    # Create lock held by another process
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    # Set very high stale age so lock won't be considered stale
    ANTIGEN_LOCK_STALE_AGE=999999999
    export ANTIGEN_LOCK_STALE_AGE

    # Set very short timeout for fast test (1 second with sleep 1 intervals)
    ANTIGEN_LOCK_TIMEOUT=1
    export ANTIGEN_LOCK_TIMEOUT

    When call acquire_antigen_cache_lock
    The status should equal 1
    The stderr should include 'Failed to acquire cache lock'
  End

  It 'waits and retries when lock is held temporarily'
    # Lock mtime is fresh so it won't be considered stale
    FAKE_EPOCH=2000000000
    FAKE_STAT_MTIME=1999999999
    export FAKE_EPOCH FAKE_STAT_MTIME

    # Create lock
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    # Release lock after 0.5 seconds in background (within 1s sleep window)
    (sleep 0.5 && rm -rf "$ANTIGEN_DOTFILES_LOCK") &

    ANTIGEN_LOCK_TIMEOUT=5
    export ANTIGEN_LOCK_TIMEOUT

    When call acquire_antigen_cache_lock
    The status should be success
    The directory "$ANTIGEN_DOTFILES_LOCK" should be exist
  End

  It 'removes stale lock older than ANTIGEN_LOCK_STALE_AGE'
    # Current time: 2000000000, lock mtime: 1999999600 (400s ago, > 300s stale age)
    FAKE_EPOCH=2000000000
    FAKE_STAT_MTIME=1999999600
    export FAKE_EPOCH FAKE_STAT_MTIME

    # Create old lock
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    When call acquire_antigen_cache_lock
    The status should be success
    The stderr should include 'Removing stale cache lock'
    The directory "$ANTIGEN_DOTFILES_LOCK" should be exist
    # New PID should be current process
    The contents of file "$ANTIGEN_DOTFILES_LOCK/pid" should equal "$$"
  End

  It 'respects ANTIGEN_LOCK_TIMEOUT environment variable'
    Skip 'Timing test removed - difficult to reliably test duration'
  End

  It 'respects ANTIGEN_LOCK_STALE_AGE environment variable'
    # Current time: 2000000000, lock mtime: 1999999850 (150s ago, > 100s custom stale age)
    FAKE_EPOCH=2000000000
    FAKE_STAT_MTIME=1999999850
    export FAKE_EPOCH FAKE_STAT_MTIME

    # Create lock that is 150 seconds old
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    # Override stale age to 100 seconds (lock should be considered stale)
    ANTIGEN_LOCK_STALE_AGE=100
    export ANTIGEN_LOCK_STALE_AGE

    When call acquire_antigen_cache_lock
    The status should be success
    The stderr should include 'Removing stale cache lock'
  End

  It 'respects ANTIGEN_DOTFILES_LOCK environment variable'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

    # Override lock location
    custom_lock="$TEST_HOME/.custom-lock-location"
    ANTIGEN_DOTFILES_LOCK="$custom_lock"
    export ANTIGEN_DOTFILES_LOCK

    When call acquire_antigen_cache_lock
    The status should be success
    The directory "$custom_lock" should be exist
  End

  It 'does not remove fresh lock during acquisition attempt'
    # Lock mtime is 10s ago, well under stale age of 999999999
    FAKE_EPOCH=2000000000
    FAKE_STAT_MTIME=1999999990
    export FAKE_EPOCH FAKE_STAT_MTIME

    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    # Set very high stale age so lock won't be removed
    ANTIGEN_LOCK_STALE_AGE=999999999
    export ANTIGEN_LOCK_STALE_AGE

    ANTIGEN_LOCK_TIMEOUT=1
    export ANTIGEN_LOCK_TIMEOUT

    When call acquire_antigen_cache_lock
    The status should equal 1
    The stderr should not include 'Removing stale'
    # Original PID should still be present
    The contents of file "$ANTIGEN_DOTFILES_LOCK/pid" should equal "99999"
  End
End

Describe 'release_antigen_cache_lock()'
  Before 'setup'
  After 'cleanup'

  It 'removes the lock directory'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

    # Create lock first
    acquire_antigen_cache_lock
    The directory "$ANTIGEN_DOTFILES_LOCK" should be exist

    # Release it
    release_antigen_cache_lock

    # Verify it's gone
    The directory "$ANTIGEN_DOTFILES_LOCK" should not be exist
  End

  It 'is idempotent (safe to call multiple times)'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

    # Create and release lock
    acquire_antigen_cache_lock
    release_antigen_cache_lock

    # Call release again (no error should occur)
    When call release_antigen_cache_lock
    The status should be success
  End

  It 'is safe to call when lock was never acquired'
    When call release_antigen_cache_lock
    The status should be success
  End

  It 'removes lock even if PID file is missing'
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    # Don't create PID file

    When call release_antigen_cache_lock
    The status should be success
    The directory "$ANTIGEN_DOTFILES_LOCK" should not be exist
  End
End

Describe 'wait_for_antigen_compile()'
  Before 'setup'
  After 'cleanup'

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
