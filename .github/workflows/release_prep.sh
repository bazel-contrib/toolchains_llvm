#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
tag=${GITHUB_REF_NAME}
# The prefix is chosen to match what GitHub generates for source archives
prefix="toolchains_llvm-${tag}"
archive="toolchains_llvm-${tag}.tar.gz"
git archive --format=tar --prefix="${prefix}/" "${tag}" | gzip >"${archive}"
sha=$(shasum -a 256 "${archive}" | cut -f1 -d' ')

sed \
  -e "s/{tag}/${tag}/g" \
  -e "s/{prefix}/${prefix}/g" \
  -e "s/{archive}/${archive}/g" \
  -e "s/{sha}/${sha}/g" \
  .github/workflows/release_notes_template.txt
