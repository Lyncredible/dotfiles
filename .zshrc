# Always update self
pushd ~/.dotfiles >/dev/null
env git pull >/dev/null || {
  printf "Warning: Failed to check update for dotfiles repo.\n"
}
popd >/dev/null

# Using zplug to manage zsh plugins
source ~/.zplug/init.zsh

# Builtin libraries from on-my-zsh
zplug "lib/directories", from:oh-my-zsh
zplug "lib/functions", from:oh-my-zsh
zplug "lib/grep", from:oh-my-zsh
zplug "lib/history", from:oh-my-zsh
zplug "lib/key-bindings", from:oh-my-zsh
zplug "lib/termsupport", from:oh-my-zsh
zplug "lib/theme-and-appearance", from:oh-my-zsh

# Plugins from oh-my-zsh
zplug "plugins/common-aliases", from:oh-my-zsh
zplug "plugins/git", from:oh-my-zsh
zplug "plugins/sublime", from:oh-my-zsh
zplug "plugins/z", from:oh-my-zsh

# Plugins from zsh-users
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-syntax-highlighting"

# Bullet train theme
setopt prompt_subst # Make sure prompt is able to be generated properly.
zplug "caiogondim/bullet-train.zsh", use:bullet-train.zsh-theme, defer:3

BULLETTRAIN_CONTEXT_BG=magenta
BULLETTRAIN_PROMPT_ORDER=(time status custom context dir ruby virtualenv nvm go git cmd_exec_time)

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
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

# work around a compaudit problem
chmod -R 755 ~/.zplug

# aliases - note there is a hard-coded assumption of .dotfiles directory
source ~/.dotfiles/.aliases

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
  zplug install
fi

# Then, source plugins and add commands to $PATH
zplug load
