#!/usr/bin/env bash
set -eu

output=$($BINARY 2>&1 || true)

for arg in "$@"; do
    echo $output | grep -q "$arg"
done
