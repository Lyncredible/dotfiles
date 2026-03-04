#!/bin/zsh
# shellcheck shell=bash disable=SC1091,SC2034

spec_helper_configure() {
  . "$SHELLSPEC_PROJECT_ROOT/common.sh"
}

# Assert a JSON key equals an expected value.
# Usage: json_value_should_eq <file> <jq_key> <expected>
json_value_should_eq() {
  local file="$1" key="$2" expected="$3"
  local actual
  actual=$(jq -r "$key" "$file")
  [ "$actual" = "$expected" ]
}
