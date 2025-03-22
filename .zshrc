# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Import common functions
source ~/.dotfiles/common.sh

update_repo() {
  git fetch >/dev/null
  if [ $? -ne 0 ]; then
    printf "Warning: Failed to fetch dotfiles repo.\n"
    return 1
  fi

  git rebase origin/master >/dev/null
  if [ $? -ne 0 ]; then
    printf "Warning: Failed to rebase dotfiles repo.\n"
    return 1
  fi
  
  return 0
}

# Update every once in a while
UPDATE_TIMESTAMP_FILE=$HOME/.dotfiles-update
DOTFILES_UPDATED=0
if ! check_up_to_date $UPDATE_TIMESTAMP_FILE; then
  printf 'Updating dotfiles...\n'
  pushd ~/.dotfiles >/dev/null
  update_repo
  if [ $? -eq 0 ]; then
    write_update_timestamp $UPDATE_TIMESTAMP_FILE
    DOTFILES_UPDATED=1
  fi
  popd >/dev/null
fi
unset UPDATE_TIMESTAMP_FILE

# Source after update - this has to be another file
source ~/.dotfiles/main.zshrc
