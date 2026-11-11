#!/bin/zsh
# shellcheck shell=bash

DATE_BIN="${DATE_BIN:-date}"
JQ_BIN="${JQ_BIN:-jq}"
GIT_BIN="${GIT_BIN:-git}"
STAT_BIN="${STAT_BIN:-stat}"
SLEEP_BIN="${SLEEP_BIN:-sleep}"
MKDIR_BIN="${MKDIR_BIN:-mkdir}"
AWK_BIN="${AWK_BIN:-/usr/bin/awk}"
CP_BIN="${CP_BIN:-/bin/cp}"
MV_BIN="${MV_BIN:-/bin/mv}"
RM_BIN="${RM_BIN:-/bin/rm}"
MKTEMP_BIN="${MKTEMP_BIN:-/usr/bin/mktemp}"

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
    "$CP_BIN" "$claude_dist" "$claude_settings"
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

# Merge repo-managed Codex defaults into config.toml without touching user-owned
# machine state such as trusted projects or MCP servers.
merge_codex_settings() {
  local codex_dist="$1"
  local codex_settings="$2"
  local codex_dir="${codex_settings:h}"
  local tmp_file

  if [[ ! -f "$codex_dist" ]]; then
    return 0
  fi

  "$MKDIR_BIN" -p "$codex_dir"

  if [[ ! -f "$codex_settings" ]]; then
    "$CP_BIN" "$codex_dist" "$codex_settings"
    return 0
  fi

  tmp_file=$("$MKTEMP_BIN" "${codex_settings}.tmp.XXXXXX") || return 1
  # shellcheck disable=SC2016
  if "$AWK_BIN" '
    BEGIN {
      managed_key = "plan_mode_reasoning_effort"
      managed_line = managed_key " = \"high\""
      in_root = 1
      wrote_managed = 0
    }

    in_root && /^[[:space:]]*\[/ {
      if (!wrote_managed) {
        print managed_line
        wrote_managed = 1
      }
      in_root = 0
      print
      next
    }

    in_root && $0 ~ "^[[:space:]]*" managed_key "[[:space:]]*=" {
      if (!wrote_managed) {
        print managed_line
        wrote_managed = 1
      }
      next
    }

    {
      print
    }

    END {
      if (!wrote_managed) {
        print managed_line
      }
    }
  ' "$codex_settings" > "$tmp_file"; then
    "$MV_BIN" "$tmp_file" "$codex_settings"
    return 0
  fi

  "$RM_BIN" -f "$tmp_file"
  return 1
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
      SKIP_CHSH=1 "$dotfiles_dir/setup.sh"
    fi
  fi
  popd >/dev/null || return 1
  unset UPDATE_BEFORE_REF
  unset UPDATE_AFTER_REF
}

# A persistent file beside Antigen's shared state. Never unlink a native lock file:
# another shell could still hold a lock on the old inode.
ANTIGEN_DOTFILES_LOCK="${ANTIGEN_DOTFILES_LOCK:-${ADOTDIR:-$HOME/.antigen}/.dotfiles-cache.lock}"
ANTIGEN_LOCK_TIMEOUT="${ANTIGEN_LOCK_TIMEOUT:-30}"  # seconds
ANTIGEN_COMPILE_TIMEOUT="${ANTIGEN_COMPILE_TIMEOUT:-5}"  # seconds (legacy Antigen)

# Use Zsh's fcntl lock on macOS/Linux/WSL; no PID files or stale-lock deletion.
# Ownership ends when this shell closes the descriptor or exits, including SIGKILL.
acquire_antigen_cache_lock() {
  local lock_file="$ANTIGEN_DOTFILES_LOCK"
  local lock_fd

  if ! zmodload zsh/system 2>/dev/null || ! zsystem supports flock; then
    printf 'Antigen: Native file locking is unavailable (zsh/system).\n' >&2
    return 1
  fi

  if [[ ! "$ANTIGEN_LOCK_TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf 'Antigen: ANTIGEN_LOCK_TIMEOUT must be a nonnegative number.\n' >&2
    return 1
  fi

  # Reopening/closing a locked file in the same process can release fcntl locks.
  # Reject nested acquisition before touching the file, preserving the outer lock.
  if [[ -n "${_ANTIGEN_DOTFILES_LOCK_FD:-}" ]]; then
    printf 'Antigen: Cache lock is already held by this shell.\n' >&2
    return 1
  fi

  "$MKDIR_BIN" -p "${lock_file:h}" || return 1
  : >> "$lock_file" || return 1
  if zsystem flock -t "$ANTIGEN_LOCK_TIMEOUT" -i 0.05 -f lock_fd "$lock_file"; then
    typeset -g _ANTIGEN_DOTFILES_LOCK_FD="$lock_fd"
    # $$ is the parent's PID inside Zsh subshells; sysparams identifies this process.
    # shellcheck disable=SC2154
    typeset -g _ANTIGEN_DOTFILES_LOCK_PID="${sysparams[pid]}"
    return 0
  fi

  printf 'Antigen: Failed to acquire cache lock within %ss\n' "$ANTIGEN_LOCK_TIMEOUT" >&2
  return 1
}

release_antigen_cache_lock() {
  # A subshell inherits our variables but does not own the parent's fcntl lock.
  if [[ -n "${_ANTIGEN_DOTFILES_LOCK_FD:-}" &&
        "${_ANTIGEN_DOTFILES_LOCK_PID:-}" == "${sysparams[pid]}" ]]; then
    zsystem flock -u "$_ANTIGEN_DOTFILES_LOCK_FD" || return 1
    unset _ANTIGEN_DOTFILES_LOCK_FD _ANTIGEN_DOTFILES_LOCK_PID
  fi
  return 0
}

# Best-effort compatibility with Antigen before v2.3, which compiled the cache
# in a disowned worker. Timestamps cannot prove that worker has finished.
# Current Antigen compiles the main cache synchronously inside `antigen apply`.
wait_for_antigen_compile() {
  if [[ -n "${_ANTIGEN_CACHE_VERSION:-}" ]]; then
    autoload -Uz is-at-least
    is-at-least 2.3.0 "${_ANTIGEN_CACHE_VERSION#v}" && return 0
  fi

  local cache_file="${ANTIGEN_CACHE:-$HOME/.antigen/init.zsh}"
  local zwc_file="${cache_file}.zwc"
  local max_wait=$(( ANTIGEN_COMPILE_TIMEOUT * 10 ))  # 0.1s intervals
  local waited=0

  # If cache doesn't exist, nothing to wait for
  [[ ! -f "$cache_file" ]] && return 0

  while [[ $waited -lt $max_wait ]]; do
    # Check if zwc exists and is newer than cache
    if [[ -f "$zwc_file" && "$zwc_file" -nt "$cache_file" ]]; then
      return 0
    fi
    "$SLEEP_BIN" 0.1
    waited=$((waited + 1))
  done

  # Timeout is not an error - zcompile might have failed or still running
  # Proceed anyway since the cache file itself is complete
  return 0
}
