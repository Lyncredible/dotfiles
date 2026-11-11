#!/bin/sh
# shellcheck disable=SC2016
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
export REPO_ROOT TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT
trap 'exit 1' INT TERM

zsh -f <<'ZSH'
setopt errexit nounset pipefail
zmodload zsh/system
zsystem supports flock

export COMMON_FILE="$REPO_ROOT/common.sh"
export ANTIGEN_DOTFILES_LOCK="$TEST_ROOT/cache.lock"
export ANTIGEN_LOCK_TIMEOUT=5
export HOME="$TEST_ROOT/home"
export ZDOTDIR="$HOME"
export NO_UV=true DOTFILES_UPDATED=0
export PATH="$HOME/bin:/usr/bin:/bin"
export FZF_APT_KEY_BINDINGS="$HOME/no-fzf"
unset ADOTDIR

typeset -A workers
cleanup_workers() {
  local worker_pid
  for worker_pid in "${(@v)workers}"; do
    kill -KILL "$worker_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
  done
}
trap cleanup_workers EXIT
trap 'exit 1' INT TERM

fail() {
  print -u2 -- "$*"
  local logfile
  for logfile in "$TEST_ROOT"/*.log(N); do
    print -u2 -- "$logfile:"
    cat "$logfile" >&2
  done
  exit 1
}

await_file() {
  local attempt
  for attempt in {1..500}; do
    [[ -f $1 ]] && return 0
    sleep 0.01
  done
  fail "Timed out waiting for $1"
}

start_worker() {
  local worker_name="$1" code="$2"
  WORKER_NAME="$worker_name" zsh -fc 'source "$COMMON_FILE"; eval "$1"' zsh "$code" \
    > "$TEST_ROOT/$worker_name.log" 2>&1 &
  workers[$worker_name]="$!"
}

join_worker() {
  local worker_name="$1" expected="${2:-0}" result=0
  wait "${workers[$worker_name]}" || result=$?
  unset "workers[$worker_name]"
  [[ $result == $expected ]] || fail "$worker_name: expected exit $expected, got $result"
}

probe_held() {
  start_worker probe 'ANTIGEN_LOCK_TIMEOUT=0.05; acquire_antigen_cache_lock'
  join_worker probe 1
  [[ $(< "$TEST_ROOT/probe.log") == *'Failed to acquire cache lock'* ]] \
    || fail 'The probe failed for a reason other than contention'
}

# Hold an old lock; nested acquisition and unowned/subshell releases must not free it.
start_worker holder '
  acquire_antigen_cache_lock || exit 1
  acquire_antigen_cache_lock && exit 1
  (release_antigen_cache_lock) || exit 1
  touch "$TEST_ROOT/held"
  while [[ ! -f $TEST_ROOT/release ]]; do sleep 0.01; done
  release_antigen_cache_lock
'
await_file "$TEST_ROOT/held"
touch -t 200001010000 "$ANTIGEN_DOTFILES_LOCK"
start_worker unowned 'release_antigen_cache_lock; release_antigen_cache_lock'
join_worker unowned
probe_held

# The contender announces its attempt before blocking; publication is gated on release.
start_worker contender '
  touch "$TEST_ROOT/attempting"
  acquire_antigen_cache_lock || exit 1
  touch "$TEST_ROOT/acquired"
  release_antigen_cache_lock
'
await_file "$TEST_ROOT/attempting"
[[ ! -f $TEST_ROOT/acquired ]] || fail 'Contender acquired a held lock'
touch "$TEST_ROOT/release"
join_worker holder
join_worker contender
[[ -f $TEST_ROOT/acquired && -f $ANTIGEN_DOTFILES_LOCK ]] || fail 'Lock handoff failed'
print 'PASS: contention, old live lock, ownership, nested acquisition, and handoff'

# Kernel recovery requires neither PID-file cleanup nor deleting the lock file.
for death_signal in TERM KILL; do
  start_worker doomed '
    acquire_antigen_cache_lock || exit 1
    touch "$TEST_ROOT/doomed-ready"
    while true; do sleep 0.01; done
  '
  await_file "$TEST_ROOT/doomed-ready"
  kill -"$death_signal" "${workers[doomed]}"
  if [[ $death_signal == TERM ]]; then expected=143; else expected=137; fi
  join_worker doomed "$expected"
  rm "$TEST_ROOT/doomed-ready"
  start_worker recovered 'acquire_antigen_cache_lock && release_antigen_cache_lock'
  join_worker recovered
  [[ -f $ANTIGEN_DOTFILES_LOCK ]] || fail 'Crash recovery unlinked the lock file'
done
print 'PASS: recovery after SIGTERM and SIGKILL'

# Multiple cold cache writers must never overlap. Read back each completed cache.
for round in 1 2 3; do
  for worker_index in {1..8}; do
    start_worker "writer-$worker_index" '
      acquire_antigen_cache_lock || exit 1
      {
        mkdir "$TEST_ROOT/critical" || exit 1
        printf "ZSH=%s\n" "$HOME/oh-my-zsh" > "$TEST_ROOT/init.zsh"
        sleep 0.01
        printf "CACHE_COMPLETE=yes\n" >> "$TEST_ROOT/init.zsh"
        zcompile "$TEST_ROOT/init.zsh" || exit 1
        source "$TEST_ROOT/init.zsh"
        [[ $ZSH == "$HOME/oh-my-zsh" && $CACHE_COMPLETE == yes ]] || exit 1
        rmdir "$TEST_ROOT/critical" || exit 1
      } always {
        release_antigen_cache_lock
      }
    '
  done
  for worker_index in {1..8}; do join_worker "writer-$worker_index"; done
done
print 'PASS: 24 concurrent cache writers, synchronous compilation, and complete reads'

# Exercise the actual configure_antigen function via normal main.zshrc sourcing.
mkdir -p "$HOME/.dotfiles" "$HOME/.antigen" "$HOME/bin"
cp "$REPO_ROOT/main.zshrc" "$HOME/.dotfiles/main.zshrc"
: > "$HOME/.dotfiles/.aliases"
: > "$HOME/.dotfiles/.p10k.zsh"
cat > "$HOME/bin/fzf" <<'FZF'
#!/bin/sh
exit 0
FZF
chmod +x "$HOME/bin/fzf"
cat > "$HOME/.antigen/antigen.zsh" <<'ANTIGEN'
antigen() {
  if [[ $1 == apply ]]; then
    touch "$TEST_ROOT/apply-ready"
    while [[ ! -f $TEST_ROOT/apply-continue ]]; do sleep 0.01; done
  fi
}
ANTIGEN
start_worker configuring '
  trap '\''touch "$TEST_ROOT/term-seen"'\'' TERM
  source "$HOME/.dotfiles/main.zshrc"
'
await_file "$TEST_ROOT/apply-ready"
kill -TERM "${workers[configuring]}"
await_file "$TEST_ROOT/term-seen"
probe_held
[[ ! -f $TEST_ROOT/apply-continue ]] || fail 'Apply should still be blocked'
touch "$TEST_ROOT/apply-continue"
join_worker configuring
start_worker after_configure 'acquire_antigen_cache_lock && release_antigen_cache_lock'
join_worker after_configure
print 'PASS: caught SIGTERM preserves the caller trap and keeps active initialization locked'
ZSH
