#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

git config user.email "you@example.com"
git config user.name "Your Name"

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
tag="${GITHUB_REF_NAME}"
commit="${GITHUB_SHA}"
# The prefix is chosen to match what GitHub generates for source archives
prefix="toolchains_llvm-${tag}"
archive="toolchains_llvm-${tag}.tar.gz"
sed -i.bak "s/0.0.0/${tag}/" MODULE.bazel && git add MODULE.bazel && git commit -m "Update version" >/dev/null
git archive --format=tar --prefix="${prefix}/" HEAD | gzip >"${archive}"
sha=$(shasum -a 256 "${archive}" | cut -f1 -d' ')

sed \
  -e "s/{tag}/${tag}/g" \
  -e "s/{commit}/${commit}/g" \
  -e "s/{prefix}/${prefix}/g" \
  -e "s/{archive}/${archive}/g" \
  -e "s/{sha}/${sha}/g" \
  .github/workflows/release_notes_template.txt
