GREP_BIN="${GREP_BIN:-grep}"
TMUX_BIN="${TMUX_BIN:-tmux}"
GIT_BIN="${GIT_BIN:-git}"
PROC_VERSION_FILE="${PROC_VERSION_FILE:-/proc/version}"
UV_BIN="${UV_BIN:-uv}"
FZF_BIN="${FZF_BIN:-fzf}"
FZF_APT_KEY_BINDINGS="${FZF_APT_KEY_BINDINGS:-/usr/share/doc/fzf/examples/key-bindings.zsh}"

configure_antigen() {
  # Acquire outer lock to protect entire antigen configuration
  # This extends protection beyond antigen's built-in lock which is released too early
  if ! acquire_antigen_cache_lock; then
    printf 'Error: Failed to acquire antigen lock, cannot proceed safely\n' >&2
    return 1
  fi

  # Ensure lock is released even if something fails
  trap 'release_antigen_cache_lock' EXIT INT TERM

  # Using antigen to manage zsh plugins
  source ~/.antigen/antigen.zsh

  # Disable oh-my-zsh's termsupport library from overriding our
  # custom terminal title set by _set_terminal_title.
  DISABLE_AUTO_TITLE="true"

  # Use oh-my-zsh
  antigen use oh-my-zsh

  # Plugins from oh-my-zsh
  antigen bundle command-not-found
  antigen bundle common-aliases
  antigen bundle colored-man-pages
  antigen bundle extract
  antigen bundle git
  antigen bundle sublime
  antigen bundle z

  # Plugins from zsh-users
  antigen bundle zsh-users/zsh-autosuggestions
  antigen bundle zsh-users/zsh-completions
  antigen bundle zsh-users/zsh-syntax-highlighting

  # Bullet train theme
  antigen theme romkatv/powerlevel10k

  # Then, source plugins and add commands to $PATH
  antigen apply

  # Wait for background zcompile to complete before releasing lock
  # This ensures no other process reads partially-compiled cache
  wait_for_antigen_compile

  # Release lock
  release_antigen_cache_lock
  trap - EXIT INT TERM

  # Update antigen whenever dotfiles auto-update succeeds (periodic)
  if [[ "${DOTFILES_UPDATED:-0}" -eq 1 ]]; then
    printf 'Updating antigen...\n'
    antigen selfupdate
    antigen update
  fi
}

is_wsl() {
  [[ -e "$PROC_VERSION_FILE" ]] && "$GREP_BIN" -q Microsoft "$PROC_VERSION_FILE"
}

selected_editor() {
  if [[ -n "$SSH_CONNECTION" ]]; then
    printf 'vim\n'
  elif is_wsl; then
    printf 'wslsubl -n -w\n'
  else
    printf 'subl -n -w\n'
  fi
}

configure_editor() {
  export EDITOR
  EDITOR="$(selected_editor)"
}

setup_path() {
  path=(
    "$HOME/bin"
    "$HOME/.dotfiles/bin"
    "$HOME/.local/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/opt/homebrew/bin"
    $path
  )
}

setup_node() {
  if [ -d "$HOME/.nodenv" ]; then
    export PATH="$HOME/.nodenv/bin:$PATH"
    eval "$(nodenv init -)"
  fi
}

setup_go() {
  export GOPATH=~/go
  export PATH="$PATH:$GOPATH/bin"
}

setup_ruby() {
  if [ -d "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
  fi
}

warn_if_uv_missing() {
  if [[ "$NO_UV" != "true" ]] && ! command_exists "$UV_BIN"; then
    printf 'WARNING: uv is not installed\n'
  fi
}

configure_homebrew() {
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ENV_HINTS=1
}

sync_claude_settings() {
  merge_claude_settings \
    "$HOME/.dotfiles/.claude/settings.json.dist" \
    "$HOME/.dotfiles/.claude/settings.json"
}

# Personalized clone when multiple github keys are present
function lynclone() {
  local git_url="$1"
  local lync_url="${git_url/github.com:/github.lync:}"
  local repo_name="${git_url##*/}"
  repo_name="${repo_name%.git}"

  "$GIT_BIN" clone "$lync_url" || return 1
  cd "$repo_name" || return 1
  "$GIT_BIN" config user.name 'Yuan Liu'
  "$GIT_BIN" config user.email lyncredible@outlook.com
  "$GIT_BIN" config commit.gpgsign false
}

# Update SSH agent on every command prompt in TMUX
_update_ssh_agent() {
  local var
  var=$("$TMUX_BIN" show-environment | "$GREP_BIN" '^SSH_AUTH_SOCK=') || return 0
  eval "export $var"
}

register_tmux_ssh_hook() {
  if [[ -n "$TMUX" ]]; then
    precmd_functions+=(_update_ssh_agent)
  fi
}

configure_ulimit() {
  # Work around bug in browserify
  ulimit -n 2560
}

source_aliases() {
  # aliases - note there is a hard-coded assumption of .dotfiles directory
  source ~/.dotfiles/.aliases
}

source_p10k() {
  # Load Powerlevel10k
  [[ ! -f ~/.dotfiles/.p10k.zsh ]] || source ~/.dotfiles/.p10k.zsh
}

source_fzf() {
  # Modern fzf integration (fzf >= 0.48.0)
  # This method is preferred as it's maintained by fzf itself
  if command_exists fzf && fzf --zsh >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
  # Fallback: fzf via Homebrew
  elif [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
  # Fallback: fzf via apt on Ubuntu
  elif [ -f "$FZF_APT_KEY_BINDINGS" ]; then
    source "$FZF_APT_KEY_BINDINGS"
  fi
}

warn_if_fzf_missing() {
  if ! command_exists "$FZF_BIN"; then
    printf 'WARNING: fzf is not installed\n'
  fi
}

pasteinit() {
  # This speeds up pasting w/ autosuggest
  # https://github.com/zsh-users/zsh-autosuggestions/issues/238
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}

pastefinish() {
  zle -N self-insert "$OLD_SELF_INSERT"
}
configure_paste_behavior() {
  zstyle :bracketed-paste-magic paste-init pasteinit
  zstyle :bracketed-paste-magic paste-finish pastefinish

  # https://github.com/zsh-users/zsh-autosuggestions/issues/351
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)
}

function reset-terminal() {
  # Reset the prompt, useful after abnormal exit from tmux
  stty sane < /dev/tty
  tput reset
  zle redisplay
}
configure_reset_terminal() {
  zle -N reset-terminal
  bindkey '^Z' reset-terminal
}

setup_whereami() {
  export WHEREAMI=$("$HOME/.local/bin/whereami" 2>/dev/null \
    || hostname -s 2>/dev/null || echo "unknown")
}

set_terminal_title() {
  precmd_functions+=(_set_terminal_title)
}

_set_terminal_title() {
  print -Pn "\e]0;%n@${WHEREAMI}:%~\a"
}

configure_editor
setup_path
setup_whereami
setup_node
setup_go
setup_ruby
warn_if_uv_missing
configure_homebrew
sync_claude_settings
register_tmux_ssh_hook
set_terminal_title
configure_ulimit
source_aliases
configure_antigen
source_p10k
source_fzf
warn_if_fzf_missing
configure_paste_behavior
configure_reset_terminal
