# Antigen Cache Race Condition Bug Analysis

## Executive Summary

Antigen's caching mechanism has a critical race condition that causes cache corruption when multiple shell sessions initialize concurrently. The bug is in the locking mechanism: the lock is released **before** cache generation starts, leaving a window where concurrent writes corrupt the cache file.

## Symptoms

- Cache file `~/.antigen/init.zsh` contains `ZSH=""` (empty string) instead of path to oh-my-zsh
- Oh-my-zsh library files fail to load silently
- Features like ls colorization stop working
- Message "Antigen: Another process in running." appears but doesn't prevent corruption

## Root Cause

**File**: `~/.antigen/src/ext/lock.zsh` and `~/.antigen/src/ext/cache.zsh`

**Problem**: Lock release happens before cache generation due to hook execution order.

### Hook Execution Flow

1. `antigen-apply` command completes
2. **Post hooks execute in registration order:**
   - `antigen-apply-lock` (releases lock) — registered in `ext/lock.zsh`
   - `antigen-apply-parallel`
   - `antigen-apply-defer`
   - `antigen-apply-cached` (generates cache) — registered in `ext/cache.zsh`

### The Race Condition

```
Time  Shell 1                        Shell 2
----  ------                         -------
T1    antigen apply completes
T2    antigen-apply-lock runs
T3      rm -f ~/.antigen/.lock       (LOCK RELEASED)
T4                                   antigen starts
T5                                   antigen-lock checks
T6                                     ~/.antigen/.lock missing ✓
T7                                     touch ~/.antigen/.lock
T8    antigen-apply-cached runs
T9      cat > ~/.antigen/init.zsh    (WRITE START)
T10                                  antigen-apply-cached runs
T11                                    cat > ~/.antigen/init.zsh  (CONCURRENT WRITE!)
T12   [CORRUPTION: both writing simultaneously]
```

### Code References

**Lock release** (`src/ext/lock.zsh`, lines ~15-19):
```zsh
antigen-apply-lock () {
  WARN "Freeing antigen-lock file at $ANTIGEN_LOCK"
  unset _ANTIGEN_LOCK_PROCESS
  rm -f $ANTIGEN_LOCK &> /dev/null  # ← RELEASED TOO EARLY
}
```

**Hook registration** (`src/ext/lock.zsh`, line ~21):
```zsh
-antigen-interactive-mode () {
  -antigen-add-hook antigen-apply post antigen-apply-lock  # ← FIRST
  ...
}
```

**Cache generation** (`src/ext/cache.zsh`, lines ~45-80):
```zsh
-antigen-cache-generate () {
  cat > $ANTIGEN_CACHE <<EOC  # ← WRITES TO init.zsh AFTER LOCK RELEASED
  #-- START ZCACHE GENERATED FILE
  ...
  EOC
  { zcompile "$ANTIGEN_CACHE" } &!  # ← Background compile also unprotected
}
```

**Hook registration** (`src/ext/cache.zsh`, line ~90):
```zsh
-antigen-interactive-mode () {
  -antigen-add-hook antigen-apply post antigen-apply-cached  # ← RUNS AFTER LOCK RELEASED
  ...
}
```

## Proposed Fix for Upstream

### Option 1: Reorder Hook Priority (Minimal Change)

Delay lock release until after cache generation completes.

**File**: `src/ext/lock.zsh`

```zsh
# Change hook registration from:
-antigen-add-hook antigen-apply post antigen-apply-lock

# To:
-antigen-add-hook antigen-apply post-post antigen-apply-lock once
```

Or explicitly set priority to run after cache generation:

```zsh
# In src/ext/cache.zsh, set cache hook priority to 5
-antigen-add-hook antigen-apply post antigen-apply-cached once 5

# In src/ext/lock.zsh, set lock release priority to 10 (runs later)
-antigen-add-hook antigen-apply post antigen-apply-lock once 10
```

### Option 2: Extend Lock Scope (Correct Fix)

Move lock release into the cache generation function itself.

**File**: `src/ext/cache.zsh`

```zsh
-antigen-cache-generate () {
  # ... existing cache generation code ...
  cat > $ANTIGEN_CACHE <<EOC
  ...
  EOC

  # Wait for background zcompile to complete
  local zwc_file="${ANTIGEN_CACHE}.zwc"
  local max_wait=50
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    if [[ -f "$zwc_file" && "$zwc_file" -nt "$ANTIGEN_CACHE" ]]; then
      break
    fi
    sleep 0.1
    waited=$((waited + 1))
  done

  # Release lock only after cache AND zcompile complete
  antigen-apply-lock
}
```

**File**: `src/ext/lock.zsh`

```zsh
# Remove automatic hook registration
# -antigen-add-hook antigen-apply post antigen-apply-lock once
# Let cache generation control when lock is released
```

### Option 3: Atomic Cache Write (Safest Fix)

Use atomic file operations to prevent partial writes.

**File**: `src/ext/cache.zsh`

```zsh
-antigen-cache-generate () {
  local cache_tmp="${ANTIGEN_CACHE}.tmp.$$"

  # Write to temporary file
  cat > "$cache_tmp" <<EOC
  ...
  EOC

  # Atomically move into place (overwrites existing)
  mv -f "$cache_tmp" "$ANTIGEN_CACHE"

  # Compile (still in background, but source file is complete)
  { zcompile "$ANTIGEN_CACHE" } &!
}
```

**Advantages:**
- Prevents partial reads during write
- Atomic mv operation (POSIX guarantee)
- Works even if lock mechanism fails
- Minimal code change

## Reproduction

```bash
# Clear cache
rm -rf ~/.antigen/.cache ~/.antigen/init.zsh

# Launch 5 shells concurrently
for i in {1..5}; do
  zsh -i -c 'echo "Shell $$: ZSH=$ZSH"' &
done
wait

# Check for corruption
grep '^[[:space:]]*ZSH=' ~/.antigen/init.zsh
# Bug present: ZSH=""
# Bug fixed: ZSH="/path/to/oh-my-zsh"
```

## Workaround (Used in Personal Dotfiles)

Added outer lock wrapper in dotfiles that extends protection through entire cache generation + zcompile completion. See `common.sh` functions: `acquire_antigen_cache_lock()`, `release_antigen_cache_lock()`, and `wait_for_antigen_compile()`.

## Impact

- **Severity**: High (silent data corruption)
- **Frequency**: Common in multi-window terminal setups, tmux, or auto-starting shells
- **Affected versions**: All versions using cache extension
- **Detection**: Cache file contains `ZSH=""` or oh-my-zsh features stop working

## Recommended Upstream Fix

**Option 3 (Atomic Cache Write)** is the safest and most minimal change:

1. Write cache to temporary file with unique name
2. Atomically move temporary file to final location
3. No hook reordering needed
4. Protects against all concurrent write scenarios
5. Simple to implement and test

This follows the standard pattern used by package managers (apt, yum) and other tools that write critical configuration files.

## Testing

After applying fix:

```bash
# Test 1: Concurrent initialization (should not corrupt)
rm -rf ~/.antigen/.cache ~/.antigen/init.zsh
for i in {1..10}; do zsh -i -c 'exit' & done; wait
grep 'ZSH=' ~/.antigen/init.zsh  # Should have path, not empty

# Test 2: Rapid sequential starts (stress test)
for i in {1..20}; do
  zsh -i -c 'exit'
done
# All should succeed without errors

# Test 3: Verify zcompile protection
stat ~/.antigen/init.zsh ~/.antigen/init.zsh.zwc
# zwc should be newer or equal to source
```

## References

- Antigen repository: https://github.com/zsh-users/antigen
- Hook system: `src/hooks.zsh`
- Lock extension: `src/ext/lock.zsh`
- Cache extension: `src/ext/cache.zsh`

---

*Document created: 2026-03-22*
*Bug discovered through personal dotfiles investigation*
*Workaround implemented and tested successfully*
