#!/bin/sh
# shellcheck disable=SC2034,SC2059

set -e

init_colors() {
  TPUT_BIN="${TPUT_BIN:-tput}"
  if command -v "$TPUT_BIN" >/dev/null 2>&1; then
    ncolors=$("$TPUT_BIN" colors 2>/dev/null || true)
  fi

  if [ -t 1 ] && [ -n "${ncolors:-}" ] && [ "${ncolors:-0}" -ge 8 ]; then
    RED=$("$TPUT_BIN" setaf 1)
    GREEN=$("$TPUT_BIN" setaf 2)
    YELLOW=$("$TPUT_BIN" setaf 3)
    BLUE=$("$TPUT_BIN" setaf 4)
    BOLD=$("$TPUT_BIN" bold)
    NORMAL=$("$TPUT_BIN" sgr0)
  else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NORMAL=""
  fi
}

set_defaults() {
  DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
  SHELLS_FILE="${SHELLS_FILE:-/etc/shells}"
  SETUP_SCRIPT="${SETUP_SCRIPT:-$DOTFILES_DIR/setup.sh}"
  GIT_BIN="${GIT_BIN:-git}"
  GREP_BIN="${GREP_BIN:-grep}"
}

check_zsh_installed() {
  count=$("$GREP_BIN" -c /zsh$ "$SHELLS_FILE" 2>/dev/null || true)
  if [ ! "${count:-0}" -ge 1 ]; then
    echo "${YELLOW}Zsh is not installed!${NORMAL} Please install zsh first!"
    return 1
  fi
}

check_git_installed() {
  if ! command -v "$GIT_BIN" >/dev/null 2>&1; then
    echo "${YELLOW}Error: git is not installed${NORMAL}"
    return 1
  fi
}

parse_clone_mode() {
  clone_mode="HTTPS"
  while [ $# -gt 0 ]; do
    if [ "$1" = "-s" ]; then
      clone_mode="SSH"
    fi
    shift
  done
}

clone_dotfiles() {
  if [ "$clone_mode" = "SSH" ]; then
    clone_url="git@github.com:Lyncredible/dotfiles.git"
  else
    clone_url="https://github.com/Lyncredible/dotfiles.git"
  fi

  if ! "$GIT_BIN" clone "$clone_url" "$DOTFILES_DIR"; then
    echo "${RED}Failed to clone dotfiles repo.${NORMAL}"
    return 1
  fi
}

run_setup_script() {
  if ! "$SETUP_SCRIPT"; then
    echo "${RED}Failed to run setup script.${NORMAL}"
    return 1
  fi
}

main() {
  init_colors
  set_defaults
  check_zsh_installed
  check_git_installed
  parse_clone_mode "$@"
  clone_dotfiles
  run_setup_script
}

main "$@"
