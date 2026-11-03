#!/usr/bin/env bash

# Ubuntu 24.04 does not have libtinfo5 in its PPAs:
#
# However, the LLVM binary releases hosted up upstream still target Ubuntu 18.04
# as of this writing and contain binaries linked against `libtinfo5`.
#
# LLVM 23's Linux LLD also requires ICU 70, which Ubuntu 24.04 replaced with
# ICU 74. Ubuntu 26.04 also dropped the libxml2.so.2 ABI used by older LLVM
# releases. Install missing compatibility libraries from the retained, immutable
# base `.deb` packages in Ubuntu 22.04's archive.
# Do not use the latest `jammy-updates` version:
# superseded update packages are removed and would make this URL expire.
# https://packages.ubuntu.com/jammy/amd64/libtinfo5/download
# https://packages.ubuntu.com/jammy/amd64/libicu70/download
# https://packages.ubuntu.com/jammy/amd64/libxml2/filelist

set -euo pipefail

pkg="$(mktemp --suffix=.deb)"
trap 'rm -f "${pkg}"' EXIT

packages=(
  https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb
  https://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu70_70.1-2_amd64.deb
)
# Keep the distro's security-updated libxml2 when it already provides this ABI.
if ! ldconfig -p | grep -F 'libxml2.so.2 ' >/dev/null; then
  packages+=(https://archive.ubuntu.com/ubuntu/pool/main/libx/libxml2/libxml2_2.9.13+dfsg-1build1_amd64.deb)
fi

for url in "${packages[@]}"; do
  curl --fail --location --show-error "${url}" --output "${pkg}"
  sudo dpkg -i "${pkg}"
done
