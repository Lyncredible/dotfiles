#!/bin/zsh
# shellcheck shell=bash

DATE_BIN="${DATE_BIN:-date}"
JQ_BIN="${JQ_BIN:-jq}"
GIT_BIN="${GIT_BIN:-git}"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

epoch_now() {
  "$DATE_BIN" +'%s'
}

read_update_timestamp() {
  local last_update_file="$1"
  if [[ -e "$last_update_file" ]]; then
    cat "$last_update_file"
  else
    printf '0\n'
  fi
}

check_up_to_date() {
  local epoch_current
  epoch_current=$(epoch_now)
  local epoch_last_update
  epoch_last_update=$(read_update_timestamp "$1")
  local update_frequency=$((60 * 60 * 24))

  if [[ "$epoch_current" -ge $((epoch_last_update + update_frequency)) ]]; then
    return 1
  fi

  return 0
}

write_update_timestamp() {
  printf '%s\n' "$(epoch_now)" > "$1"
}

merge_json_prefer_second() {
  "$JQ_BIN" -s '.[0] * .[1]' "$1" "$2" 2>/dev/null
}

# Merge settings.json.dist defaults into settings.json.
# dist keys win; extra local-only keys in settings.json are preserved.
# Args: $1 = dist file, $2 = settings file
merge_claude_settings() {
  local claude_dist="$1"
  local claude_settings="$2"
  if [[ ! -f "$claude_dist" ]]; then
    return 0
  fi

  if [[ ! -f "$claude_settings" ]]; then
    cp "$claude_dist" "$claude_settings"
    return 0
  fi

  if ! command_exists "$JQ_BIN"; then
    return 0
  fi

  local merged
  merged=$(merge_json_prefer_second "$claude_settings" "$claude_dist")
  if [[ -n "$merged" ]]; then
    printf '%s\n' "$merged" > "$claude_settings"
  fi
}

dotfiles_git() {
  "$GIT_BIN" "$@"
}

dotfiles_update_repo() {
  UPDATE_BEFORE_REF=$(dotfiles_git rev-parse --verify HEAD 2>/dev/null)
  if ! dotfiles_git fetch >/dev/null; then
    printf 'Warning: Failed to fetch dotfiles repo.\n'
    return 1
  fi

  if ! dotfiles_git rebase origin/master >/dev/null; then
    printf 'Warning: Failed to rebase dotfiles repo.\n'
    return 1
  fi

  UPDATE_AFTER_REF=$(dotfiles_git rev-parse --verify HEAD 2>/dev/null)
}

maybe_update_dotfiles() {
  local update_timestamp_file="${1:-$HOME/.dotfiles-update}"
  local dotfiles_dir="${2:-$HOME/.dotfiles}"
  DOTFILES_UPDATED=0

  if check_up_to_date "$update_timestamp_file"; then
    return 0
  fi

  printf 'Updating dotfiles...\n'
  pushd "$dotfiles_dir" >/dev/null || return 1
  if dotfiles_update_repo; then
    write_update_timestamp "$update_timestamp_file"
    DOTFILES_UPDATED=1
    if [[ "$UPDATE_BEFORE_REF" != "$UPDATE_AFTER_REF" ]]; then
      source "$dotfiles_dir/common.sh"
    fi
  fi
  popd >/dev/null || return 1
  unset UPDATE_BEFORE_REF
  unset UPDATE_AFTER_REF
}

# Antigen cache generation protection
ANTIGEN_DOTFILES_LOCK="${ANTIGEN_DOTFILES_LOCK:-$HOME/.dotfiles/.antigen-cache.lock}"
ANTIGEN_LOCK_TIMEOUT="${ANTIGEN_LOCK_TIMEOUT:-30}"  # seconds
ANTIGEN_LOCK_STALE_AGE="${ANTIGEN_LOCK_STALE_AGE:-300}"  # 5 minutes

# Acquire lock with timeout and stale lock cleanup
# Returns: 0 on success, 1 on failure
acquire_antigen_cache_lock() {
  local lock_file="$ANTIGEN_DOTFILES_LOCK"
  local timeout="$ANTIGEN_LOCK_TIMEOUT"
  local stale_age="$ANTIGEN_LOCK_STALE_AGE"
  local waited=0

  while [[ $waited -lt $timeout ]]; do
    # Check for stale lock (>5 minutes old)
    if [[ -d "$lock_file" ]]; then
      local lock_age
      lock_age=$(($(epoch_now) - $(stat -f %m "$lock_file" 2>/dev/null || echo 0)))
      if [[ $lock_age -gt $stale_age ]]; then
        printf 'Antigen: Removing stale cache lock (age: %ds)\n' "$lock_age" >&2
        rm -rf "$lock_file" 2>/dev/null
      fi
    fi

    # Try to acquire lock atomically using mkdir
    if mkdir "$lock_file" 2>/dev/null; then
      # Store PID for debugging
      echo "$$" > "$lock_file/pid"
      return 0
    fi

    # Lock held by another process, wait
    sleep 0.1
    waited=$((waited + 1))
  done

  printf 'Antigen: Failed to acquire cache lock after %ds\n' "$timeout" >&2
  return 1
}

# Release lock
release_antigen_cache_lock() {
  local lock_file="$ANTIGEN_DOTFILES_LOCK"
  if [[ -d "$lock_file" ]]; then
    rm -rf "$lock_file" 2>/dev/null
  fi
}

# Wait for background zcompile to complete
# Antigen runs zcompile in background with &! after cache generation
# We poll for .zwc file to appear and be newer than source
wait_for_antigen_compile() {
  local cache_file="${ANTIGEN_CACHE:-$HOME/.antigen/init.zsh}"
  local zwc_file="${cache_file}.zwc"
  local max_wait=50  # 5 seconds (50 × 0.1s)
  local waited=0

  # If cache doesn't exist, nothing to wait for
  [[ ! -f "$cache_file" ]] && return 0

  while [[ $waited -lt $max_wait ]]; do
    # Check if zwc exists and is newer than cache
    if [[ -f "$zwc_file" && "$zwc_file" -nt "$cache_file" ]]; then
      return 0
    fi
    sleep 0.1
    waited=$((waited + 1))
  done

  # Timeout is not an error - zcompile might have failed or still running
  # Proceed anyway since the cache file itself is complete
  return 0
}
