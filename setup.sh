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
  CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
  ANTIGEN_DIR="${ANTIGEN_DIR:-$HOME/.antigen}"
  GIT_BIN="${GIT_BIN:-git}"
  GREP_BIN="${GREP_BIN:-grep}"
  ZSH_BIN="${ZSH_BIN:-zsh}"
  CHSH_BIN="${CHSH_BIN:-chsh}"
  SKIP_CHSH="${SKIP_CHSH:-0}"
}

write_zsh_wrapper() {
  echo "source ~/.dotfiles/.zshrc" > "$HOME/.zshrc"
  echo "source ~/.zshrc_local" >> "$HOME/.zshrc"
  if [ ! -e "$HOME/.zshrc_local" ]; then
    touch "$HOME/.zshrc_local"
  fi
}

ensure_symlink_if_absent() {
  target="$1"
  link_path="$2"
  if [ ! -e "$link_path" ]; then
    ln -s "$target" "$link_path"
  fi
}

ensure_dir() {
  dir_path="$1"
  if [ ! -d "$dir_path" ]; then
    mkdir "$dir_path"
  fi
}

ensure_git_include() {
  include_path="$DOTFILES_DIR/.gitconfig"
  if ! "$GIT_BIN" config --global --get-all include.path \
    | "$GREP_BIN" -q "$include_path"; then
    "$GIT_BIN" config --global include.path "$include_path"
  fi
}

ensure_git_hooks_path() {
  "$GIT_BIN" -C "$DOTFILES_DIR" config core.hooksPath hooks
}

ensure_antigen() {
  if [ ! -d "$ANTIGEN_DIR" ]; then
    echo "${BLUE}Installing antigen...${NORMAL}"
    "$GIT_BIN" clone https://github.com/zsh-users/antigen.git "$ANTIGEN_DIR"
  fi
}

resolve_zsh_path() {
  command -v "$ZSH_BIN"
}

ensure_login_shell() {
  if [ "$SKIP_CHSH" = "1" ]; then
    return
  fi

  zsh_path=$(resolve_zsh_path)
  if [ "$zsh_path" != "$SHELL" ]; then
    "$CHSH_BIN" -s "$zsh_path"
  fi
}

main() {
  init_colors
  set_defaults
  write_zsh_wrapper
  ensure_symlink_if_absent "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
  ensure_git_include
  ensure_git_hooks_path
  ensure_symlink_if_absent "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
  ensure_symlink_if_absent "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
  ensure_symlink_if_absent "$DOTFILES_DIR/.hammerspoon" "$HOME/.hammerspoon"
  ensure_dir "$CONFIG_DIR"
  ensure_symlink_if_absent "$DOTFILES_DIR/karabiner" "$CONFIG_DIR/karabiner"
  ensure_symlink_if_absent "$DOTFILES_DIR/ghostty" "$CONFIG_DIR/ghostty"
  ensure_symlink_if_absent "$DOTFILES_DIR/.claude" "$HOME/.claude"
  ensure_antigen
  ensure_login_shell
}

main "$@"
