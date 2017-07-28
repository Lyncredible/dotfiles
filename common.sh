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
