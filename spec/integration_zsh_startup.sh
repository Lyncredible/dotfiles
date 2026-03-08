#!/bin/sh
# shellcheck disable=SC2016
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
SOURCE_HOME=${HOME}
ANTIGEN_SOURCE_DIR=${ANTIGEN_SOURCE_DIR:-$SOURCE_HOME/.antigen}

if ! command -v zsh >/dev/null 2>&1; then
  echo "Missing dependency: zsh" >&2
  exit 1
fi
ZSH_BIN=$(command -v zsh)

if [ ! -d "$ANTIGEN_SOURCE_DIR" ]; then
  echo "Missing Antigen source directory: $ANTIGEN_SOURCE_DIR" >&2
  exit 1
fi

TEST_ROOT=$(mktemp -d)
cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

TEST_HOME="$TEST_ROOT/home"
mkdir -p "$TEST_HOME/.dotfiles" "$TEST_HOME/.antigen"

cp "$REPO_ROOT/.zshrc" "$TEST_HOME/.dotfiles/.zshrc"
cp "$REPO_ROOT/main.zshrc" "$TEST_HOME/.dotfiles/main.zshrc"
cp "$REPO_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"
cp "$REPO_ROOT/.aliases" "$TEST_HOME/.dotfiles/.aliases"
cp "$REPO_ROOT/.p10k.zsh" "$TEST_HOME/.dotfiles/.p10k.zsh"
cp -R "$ANTIGEN_SOURCE_DIR"/. "$TEST_HOME/.antigen/"
chmod -R u+w "$TEST_HOME/.antigen"

mkdir -p "$TEST_HOME/.dotfiles/.claude"
cat > "$TEST_HOME/.dotfiles/.claude/settings.json.dist" <<'JSON'
{"attribution":{"commit":"","pr":""},"model":"claude-opus-4-6"}
JSON

OUTPUT=$(
  HOME="$TEST_HOME" \
  ZDOTDIR="$TEST_HOME" \
  TERM="${TERM:-xterm-256color}" \
  NO_UV=true \
  SSH_CONNECTION='' \
  TMUX='' \
  POWERLEVEL9K_DISABLE_GITSTATUS=true \
  "$ZSH_BIN" -i -c '
    source "$HOME/.dotfiles/common.sh"
    source "$HOME/.dotfiles/main.zshrc"
    print -r -- "EDITOR=$EDITOR"
    print -r -- "THEME=${POWERLEVEL9K_MODE:-unset}"
    print -r -- "LEFT=${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[*]:-unset}"
    whence -w prompt_powerlevel9k_setup
    alias venv
  ' 2>&1
)

case "$OUTPUT" in
  *"EDITOR=subl -n -w"*) ;;
  *)
    printf '%s\n' "$OUTPUT"
    echo "Expected default editor to be configured" >&2
    exit 1
    ;;
esac

case "$OUTPUT" in
  *"THEME=nerdfont-v3"*) ;;
  *)
    printf '%s\n' "$OUTPUT"
    echo "Expected Powerlevel10k mode to be configured" >&2
    exit 1
    ;;
esac

case "$OUTPUT" in
  *"LEFT=os_icon context dir vcs newline prompt_char"*) ;;
  *)
    printf '%s\n' "$OUTPUT"
    echo "Expected Powerlevel10k prompt elements to be configured" >&2
    exit 1
    ;;
esac

case "$OUTPUT" in
  *"prompt_powerlevel9k_setup: function"*) ;;
  *)
    printf '%s\n' "$OUTPUT"
    echo "Expected Powerlevel10k prompt function to be loaded" >&2
    exit 1
    ;;
esac

case "$OUTPUT" in
  *"venv='uv venv'"*) ;;
  *)
    printf '%s\n' "$OUTPUT"
    echo "Expected aliases from .aliases to be loaded" >&2
    exit 1
    ;;
esac

printf '%s\n' "$OUTPUT"
