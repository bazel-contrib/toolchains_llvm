set -exuo pipefail

if [[ $(uname -s) == "Linux" ]]; then
  LINKOPT="-Wl,--verbose"
else
  LINKOPT="-Wl,-v"
fi

bazel test \
  --crosstool_top=@llvm_toolchain//:toolchain \
  --copt=-v \
  --linkopt="${LINKOPT}" \
  --color=yes \
  --show_progress_rate_limit=30 \
  --keep_going \
  --test_output=errors \
  //...
