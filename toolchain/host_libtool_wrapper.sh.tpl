#!/usr/bin/env bash

# Some older `libtool` versions (~macOS 10.12) don't support arg files.
#
# This script flattens arg files into regular command line arguments.

args=()
for a in "${@}"; do
  if [[ ${a} =~ @.* ]]; then
    IFS=$'\n' read -d '' -r -a args_in_file < "${a:1}"
    for arg in "${args_in_file[@]}"; do
        args+=("${arg}")
    done
  else
    args+=("${a}")
  fi
done

exec "%{libtool_path}" "${args[@]}"
