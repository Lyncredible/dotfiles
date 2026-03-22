#!/bin/sh
# shellcheck disable=SC2016
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)

if ! command -v zsh >/dev/null 2>&1; then
  echo "Missing dependency: zsh" >&2
  exit 1
fi
ZSH_BIN=$(command -v zsh)

TEST_ROOT=$(mktemp -d)
cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

TEST_HOME="$TEST_ROOT/home"
mkdir -p "$TEST_HOME/.dotfiles" "$TEST_HOME/.antigen" "$TEST_HOME/bin"

cp "$REPO_ROOT/.zshrc" "$TEST_HOME/.dotfiles/.zshrc"
cp "$REPO_ROOT/main.zshrc" "$TEST_HOME/.dotfiles/main.zshrc"
cp "$REPO_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"
cp "$REPO_ROOT/.aliases" "$TEST_HOME/.dotfiles/.aliases"
cp "$REPO_ROOT/.p10k.zsh" "$TEST_HOME/.dotfiles/.p10k.zsh"

cat > "$TEST_HOME/.antigen/antigen.zsh" <<'EOF'
antigen() {
  if [ "$1" = "theme" ]; then
    prompt_powerlevel9k_setup() { :; }
  fi
}
EOF

cat > "$TEST_HOME/bin/fzf" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$TEST_HOME/bin/fzf"

mkdir -p "$TEST_HOME/.dotfiles/.claude"
cat > "$TEST_HOME/.dotfiles/.claude/settings.json.dist" <<'JSON'
{"attribution":{"commit":"","pr":""},"model":"claude-opus-4-6"}
JSON

cat > "$TEST_HOME/.zshrc" <<'EOF'
export HOME="$ZDOTDIR"
export PATH="$HOME/bin:/bin:/usr/bin"
export FZF_APT_KEY_BINDINGS="$HOME/no-fzf/key-bindings.zsh"
source "$HOME/.dotfiles/common.sh"
source "$HOME/.dotfiles/main.zshrc"
print -r -- "EDITOR=$EDITOR"
print -r -- "THEME=${POWERLEVEL9K_MODE:-unset}"
print -r -- "LEFT=${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[*]:-unset}"
whence -w prompt_powerlevel9k_setup
alias venv
exit 0
EOF

STDOUT_FILE="$TEST_ROOT/stdout"
STDERR_FILE="$TEST_ROOT/stderr"
HOME="$TEST_HOME" \
ZDOTDIR="$TEST_HOME" \
TERM="${TERM:-xterm-256color}" \
PATH="$TEST_HOME/bin:/bin:/usr/bin" \
NO_UV=true \
SSH_CONNECTION='' \
TMUX='' \
POWERLEVEL9K_DISABLE_GITSTATUS=true \
"$ZSH_BIN" -i >"$STDOUT_FILE" 2>"$STDERR_FILE"

OUTPUT=$(cat "$STDOUT_FILE")
ERROR_OUTPUT=$(cat "$STDERR_FILE")

if [ -n "$ERROR_OUTPUT" ]; then
  printf '%s\n' "$ERROR_OUTPUT" >&2
  echo "Expected zsh startup to be free of stderr output" >&2
  exit 1
fi

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
