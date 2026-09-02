#!/usr/bin/env bash

# Ubuntu 24.04 does not have libtinfo5 in its PPAs:
#
# However, the LLVM binary releases hosted up upstream still target Ubuntu 18.04
# as of this writing and contain binaries linked against `libtinfo5`.
#
# This script installs `libtinfo5` using the retained, immutable base `.deb`
# from Ubuntu 22.04's archive. Do not use the latest `jammy-updates` version:
# superseded update packages are removed and would make this URL expire.
# https://packages.ubuntu.com/jammy/amd64/libtinfo5/download

set -euo pipefail

pkg="$(mktemp --suffix=.deb)"
trap 'rm -f "${pkg}"' EXIT

curl --fail --location --show-error \
  https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb \
  --output "${pkg}"
sudo dpkg -i "${pkg}"
