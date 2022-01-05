# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Import common functions
source ~/.dotfiles/common.sh

# Update every once in a while
UPDATE_TIMESTAMP_FILE=$HOME/.dotfiles-update
if ! check_up_to_date $UPDATE_TIMESTAMP_FILE; then
  printf 'Updating dotfiles\n'
  pushd ~/.dotfiles >/dev/null
  env git pull >/dev/null
  if [ $? -ne 0 ]; then
    printf "Warning: Failed to check update for dotfiles repo.\n"
  else
    write_update_timestamp $UPDATE_TIMESTAMP_FILE
  fi
  popd >/dev/null
fi
unset UPDATE_TIMESTAMP_FILE

# Source after update - this has to be another file
source ~/.dotfiles/main.zshrc
