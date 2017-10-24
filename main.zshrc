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

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  BULLETTRAIN_CONTEXT_BG=cyan
  export EDITOR='vim'
else
  BULLETTRAIN_CONTEXT_BG=magenta
  export EDITOR='subl -n -w'
fi

export PATH="$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH"

# Node
# nvm.sh is super slow to load, default to a known version at startup
# [ -s "$HOME/.nvm/nvm.sh" ] && . $HOME/.nvm/nvm.sh
NODE_VERSION=v6.10.0
NODE_BIN=$HOME/.nvm/versions/node/$NODE_VERSION/bin
if [ -d "$NODE_BIN" ]; then
  export PATH="$PATH:$NODE_BIN"

  # This function loads nvm
  function lnvm {
    . "$HOME/.nvm/nvm.sh"
  }
fi
unset NODE_VERSION
unset NODE_BIN

# Golang
export GOROOT=/usr/local/opt/go/libexec
export GOPATH=~/gocode
export PATH="$PATH:$GOPATH/bin:$GOROOT/bin"

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

# Update every once in a while
UPDATE_TIMESTAMP_FILE=$HOME/.antigen-update
if ! check_up_to_date $UPDATE_TIMESTAMP_FILE; then
  if antigen update; then
    write_update_timestamp $UPDATE_TIMESTAMP_FILE
  fi
fi
unset UPDATE_TIMESTAMP_FILE

# Then, source plugins and add commands to $PATH
antigen apply
