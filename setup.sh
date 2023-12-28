#!/bin/sh

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors)
fi

if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NORMAL=""
fi

# Only enable exit-on-error after the non-critical colorization stuff,
# which may fail on systems lacking tput or terminfo
set -e

# Create zshrc which simplies sources the one in repo.
# Do not use a symlink because it allows customization.
echo "source ~/.dotfiles/.zshrc" > ~/.zshrc
echo "source ~/.zshrc_local" >> ~/.zshrc
if [ ! -e ~/.zshrc_local ]; then
  touch ~/.zshrc_local
fi

# Powerlevel10k
if [ ! -e ~/.p10k.zsh ]; then
  ln -s ~/.dotfiles/.p10k.zsh ~/.p10k.zsh
fi

# git config
if [ ! $(git config --global --get-all include.path | grep '~/.dotfiles/.gitconfig') ]; then
  git config --global include.path '~/.dotfiles/.gitconfig'
fi

# .vimrc
if [ ! -e ~/.vimrc ]; then
  ln -s ~/.dotfiles/.vimrc ~/.vimrc
fi

# Hammerspoon config
if [ ! -d ~/.hammerspoon ]; then
  ln -s ~/.dotfiles/.hammerspoon ~/.hammerspoon
fi

# Karabiner config
if [ ! -d ~/.config/karabiner ]; then
  if [ ! -d ~/.config ]; then
    mkdir ~/.config
  fi
  ln -s ~/.dotfiles/karabiner ~/.config/karabiner
fi

# Install antigen
ANTIGEN_DIR=$HOME/.antigen
if [ ! -d "$ANTIGEN_DIR" ]; then
  printf "${BLUE}Installing antigen...${NORMAL}\n"

  git clone https://github.com/zsh-users/antigen.git $ANTIGEN_DIR
fi
unset ANTIGEN_DIR

if [ ! "$(which zsh)" = "$SHELL" ]; then
  chsh -s $(which zsh)
fi
