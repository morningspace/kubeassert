#!/bin/bash

case $1 in
  assert)
    command_script=$(dirname $0)/cases/$2.sh
    command_args=${@:3}
    ;;
  fix)
    command_script=$(dirname $0)/lib/fix.sh
    command_args=${@:2}
    ;;
  *)
    echo 'Argument "'$command_name'" not known.' ;;
esac

if [[ -x $command_script ]]; then
  $command_script $command_args
else
  echo 'File "'$command_script'" not found or not excutable.'
fi
