# This files can be used to automatically run installation in login shell

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


# Make sure zsh is installed
CHECK_ZSH_INSTALLED=$(grep /zsh$ /etc/shells | wc -l)
if [ ! $CHECK_ZSH_INSTALLED -ge 1 ]; then
  printf "${YELLOW}Zsh is not installed!${NORMAL} Please install zsh first!\n"
  exit 1
fi
unset CHECK_ZSH_INSTALLED

# Check if git is installed
hash git >/dev/null 2>&1 || {
  echo "${YELLOW}Error: git is not installed${NORMAL}"
  exit 1
}

# Install dotfiles
DOTFILES_DIR=$HOME/.dotfiles
if [ ! -d "$DOTFILES_DIR" ]; then
  printf "${BLUE}Installing dotfiles...${NORMAL}\n"

  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/Lyncredible/dotfiles/master/install.sh | sh
fi
unset DOTFILES_DIR

# Invoke zsh
export SHELL=/bin/zsh
[ -z "$ZSH_VERSION" ] && exec /bin/zsh -l
