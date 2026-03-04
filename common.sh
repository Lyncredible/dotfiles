#!/bin/sh

function check_up_to_date() {
  local epochCurrent=`date +'%s'`
  local epochLastUpdate=0
  local updateFrequency=`expr 60 \* 60 \* 24`

  local lastUpdateFile="$1"

  if [ -e "$lastUpdateFile" ]; then
    epochLastUpdate=`cat $lastUpdateFile`
  fi

  if [ $epochCurrent -ge `expr $epochLastUpdate + $updateFrequency` ]; then
    return -1 # not up to date
  else
    return 0 # up to date
  fi
}

function write_update_timestamp() {
  local epochCurrent=`date +'%s'`
  echo $epochCurrent > $1
}

# Merge settings.json.dist defaults into settings.json.
# dist keys win; extra local-only keys in settings.json are preserved.
# Args: $1 = dist file, $2 = settings file
function merge_claude_settings() {
  local _claude_dist="$1"
  local _claude_settings="$2"
  if [[ -f "$_claude_dist" ]]; then
    if [[ ! -f "$_claude_settings" ]]; then
      cp "$_claude_dist" "$_claude_settings"
    elif command -v jq > /dev/null; then
      local _merged
      _merged=$(jq -s '.[0] * .[1]' "$_claude_settings" "$_claude_dist" 2>/dev/null)
      if [[ $? -eq 0 && -n "$_merged" ]]; then
        printf '%s\n' "$_merged" > "$_claude_settings"
      fi
    fi
  fi
}
