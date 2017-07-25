# Using zplug to manage zsh plugins
source ~/.zplug/init.zsh

# Basic oh-my-zsh theme for colorful ls
zplug "lib/theme-and-appearance", from:oh-my-zsh

# Plugins from oh-my-zsh
zplug "plugins/common-aliases", from:oh-my-zsh
zplug "plugins/git", from:oh-my-zsh
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

# Python
[ -s "/usr/local/bin/virtualenvwrapper.sh" ] && . /usr/local/bin/virtualenvwrapper.sh

# Node
[ -s "$HOME/.nvm/nvm.sh" ] && . $HOME/.nvm/nvm.sh

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

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
  zplug install
fi

# Then, source plugins and add commands to $PATH
zplug load
