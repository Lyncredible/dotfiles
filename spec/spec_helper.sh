#!/bin/zsh
# shellcheck shell=bash disable=SC1091,SC2034

spec_helper_configure() {
  . "$SHELLSPEC_PROJECT_ROOT/common.sh"
}

create_test_root() {
  TEST_DIR=$(mktemp -d)
  TEST_HOME="$TEST_DIR/home"
  TEST_BIN="$TEST_HOME/bin"
  /bin/mkdir -p "$TEST_HOME" "$TEST_BIN"
}

cleanup_test_root() {
  /bin/rm -rf "$TEST_DIR"
}

make_stub() {
  local name="$1"
  local stub_path="$TEST_BIN/$name"
  : > "$stub_path"
  while IFS= read -r line; do
    printf '%s\n' "$line" >> "$stub_path"
  done
  /bin/chmod +x "$stub_path"
}

write_fake_grep() {
  make_stub grep <<'STUB'
#!/bin/sh
matches_line() {
  line="$1"
  pattern="$2"

  anchored_start=0
  anchored_end=0
  case "$pattern" in
    ^*) anchored_start=1; pattern=${pattern#^} ;;
  esac
  case "$pattern" in
    *\$) anchored_end=1; pattern=${pattern%\$} ;;
  esac

  if [ "$anchored_start" -eq 1 ] && [ "$anchored_end" -eq 1 ]; then
    [ "$line" = "$pattern" ]
    return
  fi
  if [ "$anchored_start" -eq 1 ]; then
    case "$line" in
      "$pattern"*) return 0 ;;
    esac
    return 1
  fi
  if [ "$anchored_end" -eq 1 ]; then
    case "$line" in
      *"$pattern") return 0 ;;
    esac
    return 1
  fi
  case "$line" in
    *"$pattern"*) return 0 ;;
  esac
  return 1
}

mode="match"
if [ "$1" = "-c" ]; then
  mode="count"
  pattern="$2"
  file="$3"
  count=0
  while IFS= read -r line; do
    if matches_line "$line" "$pattern"; then
      count=$((count + 1))
    fi
  done < "$file"
  printf '%s\n' "$count"
  exit 0
fi

if [ "$1" = "-q" ]; then
  mode="quiet"
  pattern="$2"
  shift 2
else
  pattern="$1"
  shift
fi

if [ "$#" -gt 0 ]; then
  input=$(/bin/cat "$1")
else
  input=$(/bin/cat)
fi

while IFS= read -r line; do
  if matches_line "$line" "$pattern"; then
    [ "$mode" = "match" ] && printf '%s\n' "$line"
    exit 0
  fi
done <<EOF
$input
EOF
exit 1
STUB
}

write_fake_date() {
  make_stub date <<'STUB'
#!/bin/sh
printf '%s\n' "${FAKE_EPOCH:?}"
STUB
}

write_fake_stat() {
  make_stub stat <<'STUB'
#!/bin/sh
printf '%s\n' "${FAKE_STAT_MTIME:?}"
STUB
}

symlink_to() {
  local link_path="$1"
  local target="$2"
  local readlink_bin="${READLINK_BIN:-readlink}"
  [ -L "$link_path" ] && [ "$("$readlink_bin" "$link_path")" = "$target" ]
}

json_value_should_eq() {
  local file="$1" key="$2" expected="$3"
  local jq_bin="${JQ_BIN:-jq}"
  local actual
  actual=$("$jq_bin" -r "$key" "$file")
  [ "$actual" = "$expected" ]
}

different_from() {
  local expected="$1"
  local value
  value=$(cat)
  [ "$value" != "$expected" ]
}

recent_epoch() {
  local before="$1"
  local value
  value=$(cat)
  [ "$value" -ge "$before" ]
}
