os="$(uname -s | tr "[:upper:]" "[:lower:]")"
readonly os

arch="$(uname -m)"
if [[ "${arch}" == "x86_64" ]]; then
  arch="amd64"
elif [[ "${arch}" == "aarch64" ]]; then
  arch="arm64"
else
  >&2 echo "Unknown architecture: ${arch}"
fi
readonly arch

# Use bazelisk to catch migration problems.
readonly bazelisk_version="v1.10.1"
readonly url="https://github.com/bazelbuild/bazelisk/releases/download/${bazelisk_version}/bazelisk-${os}-${arch}"
bazel="${TMPDIR:-/tmp}/bazelisk"
readonly bazel

readonly common_test_args=(
  --incompatible_enable_cc_toolchain_resolution
  --symlink_prefix=/
  --color=yes
  --show_progress_rate_limit=30
  --keep_going
  --test_output=errors
)

curl -L -sSf -o "${bazel}" "${url}"
chmod a+x "${bazel}"
