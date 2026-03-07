#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

different_from() {
  local expected="$1"
  local value
  value=$(cat)
  [ "$value" != "$expected" ]
}

setup() {
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  mkdir -p "$TEST_HOME/.dotfiles" "$TEST_HOME/bin"

  cp "$SHELLSPEC_PROJECT_ROOT/.zshrc" "$TEST_HOME/.dotfiles/.zshrc"
  cp "$SHELLSPEC_PROJECT_ROOT/common.sh" "$TEST_HOME/.dotfiles/common.sh"

  cat >> "$TEST_HOME/.dotfiles/common.sh" <<'EOF'
_common_source_count_file="$HOME/.common_source_count"
if [ -f "$_common_source_count_file" ]; then
  _common_source_count=$(cat "$_common_source_count_file")
else
  _common_source_count=0
fi
echo $((_common_source_count + 1)) > "$_common_source_count_file"
unset _common_source_count_file
unset _common_source_count
EOF

  cat > "$TEST_HOME/.dotfiles/main.zshrc" <<'EOF'
printf '%s\n' "${DOTFILES_UPDATED:-unset}" > "$HOME/.dotfiles_updated_seen"
EOF

  cat > "$TEST_HOME/bin/git" <<'EOF'
#!/bin/sh
echo "$*" >> "$HOME/.git_calls"

if [ "$1" = "fetch" ]; then
  [ "$MOCK_GIT_FETCH_FAIL" = "1" ] && exit 1
  exit 0
fi

if [ "$1" = "rebase" ]; then
  [ "$MOCK_GIT_REBASE_FAIL" = "1" ] && exit 1
  exit 0
fi

if [ "$1" = "rev-parse" ]; then
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
  exit 0
fi

exit 0
EOF
  chmod +x "$TEST_HOME/bin/git"
}

cleanup() {
  rm -rf "$TEST_DIR"
}

run_startup() {
  HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" zsh -c 'source "$HOME/.dotfiles/.zshrc"'
}

Describe '.zshrc auto-update flow'
  Before 'setup'
  After 'cleanup'

  It 'marks update and re-sources common.sh when HEAD changes'
    old_epoch=$(( $(date +'%s') - 90000 ))
    echo "$old_epoch" > "$TEST_HOME/.dotfiles-update"
    When run env MOCK_GIT_BEFORE_REF=old-ref MOCK_GIT_AFTER_REF=new-ref HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" zsh -c 'source "$HOME/.dotfiles/.zshrc"'
    The status should be success
    The output should include 'Updating dotfiles...'
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '1'
    The contents of file "$TEST_HOME/.common_source_count" should equal '2'
    The contents of file "$TEST_HOME/.dotfiles-update" should satisfy different_from "$old_epoch"
  End

  It 'refreshes timestamp and marks DOTFILES_UPDATED=1 when HEAD is unchanged'
    old_epoch=$(( $(date +'%s') - 90000 ))
    echo "$old_epoch" > "$TEST_HOME/.dotfiles-update"
    When run env MOCK_GIT_BEFORE_REF=same-ref MOCK_GIT_AFTER_REF=same-ref HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" zsh -c 'source "$HOME/.dotfiles/.zshrc"'
    The status should be success
    The output should include 'Updating dotfiles...'
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '1'
    The contents of file "$TEST_HOME/.common_source_count" should equal '1'
    The contents of file "$TEST_HOME/.dotfiles-update" should satisfy different_from "$old_epoch"
  End

  It 'skips git update checks when timestamp is current'
    date +'%s' > "$TEST_HOME/.dotfiles-update"
    When run run_startup
    The status should be success
    The output should not include 'Updating dotfiles...'
    The file "$TEST_HOME/.git_calls" should not be exist
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '0'
    The contents of file "$TEST_HOME/.common_source_count" should equal '1'
  End

  It 'does not refresh timestamp or mark updated when fetch fails'
    old_epoch=$(( $(date +'%s') - 90000 ))
    echo "$old_epoch" > "$TEST_HOME/.dotfiles-update"
    When run env MOCK_GIT_FETCH_FAIL=1 HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" zsh -c 'source "$HOME/.dotfiles/.zshrc"'
    The status should be success
    The output should include 'Updating dotfiles...'
    The output should include 'Warning: Failed to fetch dotfiles repo.'
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '0'
    The contents of file "$TEST_HOME/.common_source_count" should equal '1'
    The contents of file "$TEST_HOME/.dotfiles-update" should equal "$old_epoch"
    The contents of file "$TEST_HOME/.git_calls" should not include 'rebase origin/master'
  End

  It 'does not refresh timestamp or mark updated when rebase fails'
    old_epoch=$(( $(date +'%s') - 90000 ))
    echo "$old_epoch" > "$TEST_HOME/.dotfiles-update"
    When run env MOCK_GIT_REBASE_FAIL=1 HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" zsh -c 'source "$HOME/.dotfiles/.zshrc"'
    The status should be success
    The output should include 'Updating dotfiles...'
    The output should include 'Warning: Failed to rebase dotfiles repo.'
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '0'
    The contents of file "$TEST_HOME/.common_source_count" should equal '1'
    The contents of file "$TEST_HOME/.dotfiles-update" should equal "$old_epoch"
  End

  It 'updates dotfiles when timestamp file is missing'
    rm -f "$TEST_HOME/.dotfiles-update"
    When run env MOCK_GIT_BEFORE_REF=same-ref MOCK_GIT_AFTER_REF=same-ref HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" zsh -c 'source "$HOME/.dotfiles/.zshrc"'
    The status should be success
    The output should include 'Updating dotfiles...'
    The contents of file "$TEST_HOME/.dotfiles_updated_seen" should equal '1'
    The file "$TEST_HOME/.dotfiles-update" should be exist
    The contents of file "$TEST_HOME/.common_source_count" should equal '1'
  End
End
