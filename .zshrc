# Always update self
pushd ~/.dotfiles >/dev/null
env git pull >/dev/null || {
  printf "Warning: Failed to check update for dotfiles repo.\n"
}
popd >/dev/null

# Source after update - this has to be another file
source ~/.dotfiles/main.zshrc
