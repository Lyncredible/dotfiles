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

# Install antigen
ANTIGEN_DIR=$HOME/.antigen
if [ ! -d "$ANTIGEN_DIR" ]; then
  printf "${BLUE}Installing antigen...${NORMAL}\n"

  git clone https://github.com/zsh-users/antigen.git $ANTIGEN_DIR
fi
unset ANTIGEN_DIR

chsh -s $(which zsh)
