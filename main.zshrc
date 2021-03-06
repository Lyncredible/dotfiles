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
antigen theme https://github.com/caiogondim/bullet-train-oh-my-zsh-theme bullet-train
BULLETTRAIN_PROMPT_ORDER=(time status custom context dir ruby virtualenv nvm go git cmd_exec_time)

# Preferred editor
if [[ -n $SSH_CONNECTION ]]; then
  # Over SSH
  BULLETTRAIN_CONTEXT_BG=cyan
  export EDITOR='vim'
elif [ -e /proc/version ] && grep -q Microsoft /proc/version; then
  # Windows Subsystem for Linux
  BULLETTRAIN_CONTEXT_BG=magenta
  export EDITOR='wslsubl -n -w'
else
  # Regular setup
  BULLETTRAIN_CONTEXT_BG=magenta
  export EDITOR='subl -n -w'
fi

export PATH="$HOME/bin:$HOME/.dotfiles/bin:/usr/local/bin:/usr/local/sbin:$PATH"

# Node
# nvm.sh is super slow to load, default to a known version at startup
# [ -s "$HOME/.nvm/nvm.sh" ] && . $HOME/.nvm/nvm.sh
NVM_HOME=$HOME/.nvm
if [ -d "$NVM_HOME" ]; then
  # This function loads nvm
  export NVM_DIR="$NVM_HOME"
  function lnvm {
    . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  }

  NVM_DEFAULT=$NVM_HOME/alias/default
  if [ -e "$NVM_DEFAULT" ]; then
    NODE_VERSION=`cat $NVM_DEFAULT`
    NODE_BIN=$HOME/.nvm/versions/node/v$NODE_VERSION/bin

    if [ -d "$NODE_BIN" ]; then
      export PATH="$PATH:$NODE_BIN"
    fi
  fi
fi
unset NODE_VERSION
unset NODE_BIN
unset NVM_HOME
unset NVM_DEFAULT

# Golang
export GOPATH=~/go
export PATH="$PATH:$GOPATH/bin"

# Ruby
if [ -d "$HOME/.rbenv" ]; then
  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
  export PATH="$PATH:$HOME/.rbenv/bin"
  eval "$(rbenv init -)"
fi

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

# fzf is installed via brew
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

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
