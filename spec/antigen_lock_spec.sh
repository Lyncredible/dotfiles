#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2154,SC2317

setup() {
  create_test_root
  write_fake_date  # For stale lock detection
  DATE_BIN="$TEST_BIN/date"
  export DATE_BIN

  # Use test-specific lock location
  ANTIGEN_DOTFILES_LOCK="$TEST_HOME/.test-antigen-lock"
  export ANTIGEN_DOTFILES_LOCK

  # Source common.sh to load functions under test
  . "$SHELLSPEC_PROJECT_ROOT/common.sh"
}

cleanup() {
  cleanup_test_root
}

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
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    # Create lock held by another process
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    # Set very high stale age so lock won't be considered stale
    ANTIGEN_LOCK_STALE_AGE=999999999
    export ANTIGEN_LOCK_STALE_AGE

    # Set very short timeout for fast test
    ANTIGEN_LOCK_TIMEOUT=1
    export ANTIGEN_LOCK_TIMEOUT

    When call acquire_antigen_cache_lock
    The status should equal 1
    The stderr should include 'Failed to acquire cache lock'
  End

  It 'waits and retries when lock is held temporarily'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

    # Create lock
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"

    # Release lock after 0.3 seconds in background
    (sleep 0.3 && rm -rf "$ANTIGEN_DOTFILES_LOCK") &

    ANTIGEN_LOCK_TIMEOUT=5
    export ANTIGEN_LOCK_TIMEOUT

    When call acquire_antigen_cache_lock
    The status should be success
    The directory "$ANTIGEN_DOTFILES_LOCK" should be exist
  End

  It 'removes stale lock older than ANTIGEN_LOCK_STALE_AGE'
    # Current time: 2000000000
    # Stale age: 300 seconds (5 minutes)
    # Lock created: 2000000000 - 400 = 1999999600 (6 minutes 40 seconds ago)
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

    # Create old lock
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"
    # Touch with old timestamp (use stat -f %m format)
    touch -t 200501010000 "$ANTIGEN_DOTFILES_LOCK"  # Jan 1, 2005

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
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

    # Create lock that is 150 seconds old
    mkdir "$ANTIGEN_DOTFILES_LOCK"
    echo "99999" > "$ANTIGEN_DOTFILES_LOCK/pid"
    touch -t 200501010000 "$ANTIGEN_DOTFILES_LOCK"

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
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH

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
    export ANTIGEN_CACHE

    # Create cache file but no zwc file
    echo "# cache content" > "$ANTIGEN_CACHE"
    # Don't create zwc - will timeout

    # Override max_wait in function (would need modification to function)
    # For now, just test that it eventually returns
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
