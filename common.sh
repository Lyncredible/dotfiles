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
