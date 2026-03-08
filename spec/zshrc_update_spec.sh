#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
  ZSH_BIN=$(command -v zsh)
  write_fake_date

  mkdir -p "$TEST_HOME/.dotfiles"
  cp "$SHELLSPEC_PROJECT_ROOT/.zshrc" "$TEST_HOME/.dotfiles/.zshrc"
  cp "$SHELLSPEC_PROJECT_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"

  cat > "$TEST_HOME/.dotfiles/main.zshrc" <<'FILE'
printf '%s\n' "${DOTFILES_UPDATED:-unset}" > "$HOME/.dotfiles_updated_seen"
FILE

  make_stub git <<'STUB'
#!/bin/sh
echo "$*" >> "$HOME/.git_calls"
if [ "$1" = 'fetch' ] && [ "$MOCK_GIT_FETCH_FAIL" = '1' ]; then
  exit 1
fi
if [ "$1" = 'rebase' ] && [ "$MOCK_GIT_REBASE_FAIL" = '1' ]; then
  exit 1
fi
if [ "$1" = 'rev-parse' ]; then
  count_file="$HOME/.git_rev_parse_count"
  count=0
  [ -f "$count_file" ] && count=$(cat "$count_file")
  count=$((count + 1))
  echo "$count" > "$count_file"
  if [ "$count" -eq 1 ]; then
    printf '%s\n' "${MOCK_GIT_BEFORE_REF:-same-ref}"
  else
    printf '%s\n' "${MOCK_GIT_AFTER_REF:-same-ref}"
  fi
fi
STUB
}

cleanup() {
  cleanup_test_root
}

run_update_helper() {
  HOME="$TEST_HOME" \
  PATH="$TEST_BIN:/bin:/usr/bin" \
  DATE_BIN="$TEST_BIN/date" \
  GIT_BIN="$TEST_BIN/git" \
  zsh -c '
    source "$HOME/.dotfiles/common.sh"
    maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
    print -r -- "$DOTFILES_UPDATED"
  '
}

run_update_helper_with_globals() {
  HOME="$TEST_HOME" \
  PATH="$TEST_BIN:/bin:/usr/bin" \
  DATE_BIN="$TEST_BIN/date" \
  GIT_BIN="$TEST_BIN/git" \
  zsh -c '
    source "$HOME/.dotfiles/common.sh"
    maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
    print -r -- "$DOTFILES_UPDATED"
    print -r -- "${UPDATE_BEFORE_REF-unset}:${UPDATE_AFTER_REF-unset}"
  '
}

Describe 'dotfiles update helper'
  Before 'setup'
  After 'cleanup'

  It 'marks update when HEAD changes'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_BEFORE_REF=old-ref \
      MOCK_GIT_AFTER_REF=new-ref \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      zsh -c '
        source "$HOME/.dotfiles/common.sh"
        maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
        print -r -- "$DOTFILES_UPDATED"
      '
    The status should be success
    The output should include 'Updating dotfiles...'
    The output should include '1'
    The contents of file "$TEST_HOME/.dotfiles-update" should equal '2000000000'
  End

  It 'cleans up update ref globals after a successful update'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_BEFORE_REF=old-ref \
      MOCK_GIT_AFTER_REF=new-ref \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      zsh -c '
        source "$HOME/.dotfiles/common.sh"
        maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
        print -r -- "${UPDATE_BEFORE_REF-unset}:${UPDATE_AFTER_REF-unset}"
      '
    The status should be success
    The output should include 'Updating dotfiles...'
    The output should include 'unset:unset'
  End

  It 'refreshes timestamp when HEAD is unchanged'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_BEFORE_REF=same-ref \
      MOCK_GIT_AFTER_REF=same-ref \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      zsh -c '
        source "$HOME/.dotfiles/common.sh"
        maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
        print -r -- "$DOTFILES_UPDATED"
      '
    The status should be success
    The output should include 'Updating dotfiles...'
    The output should include '1'
    The contents of file "$TEST_HOME/.dotfiles-update" should equal '2000000000'
  End

  It 'leaves DOTFILES_UPDATED at 0 when timestamp is current'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999999000 > "$TEST_HOME/.dotfiles-update"
    When run run_update_helper_with_globals
    The status should be success
    The output should include '0'
    The output should include 'unset:unset'
    The file "$TEST_HOME/.git_calls" should not be exist
  End

  It 'does not refresh timestamp when fetch fails'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_FETCH_FAIL=1 \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      zsh -c '
        source "$HOME/.dotfiles/common.sh"
        maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
        print -r -- "$DOTFILES_UPDATED"
      '
    The status should be success
    The output should include 'Warning: Failed to fetch dotfiles repo.'
    The output should include '0'
    The contents of file "$TEST_HOME/.dotfiles-update" should equal '1999910000'
  End

  It 'does not refresh timestamp when rebase fails'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_REBASE_FAIL=1 \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      zsh -c '
        source "$HOME/.dotfiles/common.sh"
        maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
        print -r -- "$DOTFILES_UPDATED"
      '
    The status should be success
    The output should include 'Warning: Failed to rebase dotfiles repo.'
    The output should include '0'
    The contents of file "$TEST_HOME/.dotfiles-update" should equal '1999910000'
  End

  It 'updates when the timestamp file is missing'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    rm -f "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_BEFORE_REF=same-ref \
      MOCK_GIT_AFTER_REF=same-ref \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      zsh -c '
        source "$HOME/.dotfiles/common.sh"
        maybe_update_dotfiles "$HOME/.dotfiles-update" "$HOME/.dotfiles"
        print -r -- "$DOTFILES_UPDATED"
      '
    The status should be success
    The output should include 'Updating dotfiles...'
    The output should include '1'
    The file "$TEST_HOME/.dotfiles-update" should be exist
    The contents of file "$TEST_HOME/.dotfiles-update" should equal '2000000000'
  End
End

Describe '.zshrc startup smoke test'
  Before 'setup'
  After 'cleanup'

  It 'passes DOTFILES_UPDATED through to main.zshrc after a successful update'
    FAKE_EPOCH=2000000000
    export FAKE_EPOCH
    echo 1999910000 > "$TEST_HOME/.dotfiles-update"
    When run env \
      MOCK_GIT_BEFORE_REF=same-ref \
      MOCK_GIT_AFTER_REF=same-ref \
      HOME="$TEST_HOME" \
      PATH="$TEST_BIN:/bin:/usr/bin" \
      DATE_BIN="$TEST_BIN/date" \
      GIT_BIN="$TEST_BIN/git" \
      "$ZSH_BIN" -c 'source "$HOME/.dotfiles/.zshrc"'
    The status should be success
    The output should include 'Updating dotfiles...'
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '1'
  End
End
