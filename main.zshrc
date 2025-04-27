# Using antigen to manage zsh plugins
source ~/.antigen/antigen.zsh

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

# Preferred editor
if [[ -n $SSH_CONNECTION ]]; then
  # Over SSH
  export EDITOR='vim'
elif [ -e /proc/version ] && grep -q Microsoft /proc/version; then
  # Windows Subsystem for Linux
  export EDITOR='wslsubl -n -w'
else
  # Regular setup
  export EDITOR='subl -n -w'
fi

export PATH="$HOME/bin:$HOME/.dotfiles/bin:$HOME/.local/bin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:$PATH"

# Node
NVM_HOME=$HOME/.nvm
if [ -d "$NVM_HOME" ]; then
  . "$NVM_HOME/nvm.sh"
  [ -s "$NVM_HOME/bash_completion" ] && . "$NVM_HOME/bash_completion"
fi
unset NVM_HOME

# Golang
export GOPATH=~/go
export PATH="$PATH:$GOPATH/bin"

# Ruby
if [ -d "$HOME/.rbenv" ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
fi

# Python
if ! command -v uv > /dev/null; then
  echo 'WARNING: uv is not installed'
fi

# Homebrew
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1

# Personalized clone when multiple github keys are present
function lynclone() {
  GIT_URL=$1
  LYNC_URL=`echo $GIT_URL | sed 's/github\.com\:/github\.lync\:/g'`
  REPO_NAME=`echo $GIT_URL | sed 's/[^\/]*\/\([^\.]*\)\.git/\1/g'`
  git clone $LYNC_URL
  cd $REPO_NAME
  git config user.name 'Yuan Liu'
  git config user.email lyncredible@outlook.com
  git config commit.gpgsign false
}

# Update SSH agent on every command prompt in TMUX
_update_ssh_agent() {
    local var
    var=$(tmux show-environment |grep '^SSH_AUTH_SOCK=')
    if [ "$?" -eq 0 ]; then
        eval "export $var"
    fi
}
if [[ -n "$TMUX" ]]; then
    precmd_functions+=(_update_ssh_agent)
fi

# Work around bug in browserify
ulimit -n 2560

# aliases - note there is a hard-coded assumption of .dotfiles directory
source ~/.dotfiles/.aliases

# Then, source plugins and add commands to $PATH
antigen apply

# Update antigen whenever the dotfiles repo is updated
if [ $DOTFILES_UPDATED -eq 1 ]; then
  printf "Updating antigen...\n"
  antigen selfupdate
  antigen update
fi

# Load Powerlevel10k
[[ ! -f ~/.dotfiles/.p10k.zsh ]] || source ~/.dotfiles/.p10k.zsh

# fzf via brew
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf via apt on Ubuntu
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh

if ! command -v fzf > /dev/null; then
  echo 'WARNING: fzf is not installed'
fi

# This speeds up pasting w/ autosuggest
# https://github.com/zsh-users/zsh-autosuggestions/issues/238
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}

pastefinish() {
  zle -N self-insert $OLD_SELF_INSERT
}
zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

# https://github.com/zsh-users/zsh-autosuggestions/issues/351
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)
