#!/bin/sh
# shellcheck shell=bash disable=SC2016

setup() {
  create_test_root
  REPO="$TEST_DIR/repo"
  git init -q -b master "$REPO"
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
}

cleanup() {
  cleanup_test_root
}

# Run a command in zsh with .aliases loaded, inside the test repo.
run_with_aliases() {
  (cd "$REPO" && zsh -c "
    source '$SHELLSPEC_PROJECT_ROOT/.aliases'
    eval '$1'
  ")
}

Describe '.aliases'
  Before 'setup'
  After 'cleanup'

  It 'gbdm deletes merged branches but keeps the current one, master, main, and dev'
    for branch in merged-a merged-b main dev develop-x; do
      git -C "$REPO" branch "$branch"
    done
    git -C "$REPO" checkout -q -b unmerged
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
    git -C "$REPO" checkout -q master
    When run run_with_aliases 'gbdm >/dev/null; git branch --format="%(refname:short)"'
    The status should be success
    The output should equal "$(printf '%s\n' dev main master unmerged)"
  End

  It 'gbdm keeps a branch checked out in another worktree'
    git -C "$REPO" worktree add -q -b in-worktree "$TEST_DIR/wt"
    # Nothing to delete: xargs -r keeps `git branch -d` from failing with no names.
    When run run_with_aliases 'gbdm && git branch --format="%(refname:short)"'
    The status should be success
    The output should equal "$(printf '%s\n' in-worktree master)"
  End
End
