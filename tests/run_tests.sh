set -exuo pipefail

bazel test \
  --crosstool_top=@llvm_toolchain//:toolchain \
  --copt=-v \
  --linkopt=-Wl,-t \
  --color=yes \
  --show_progress_rate_limit=30 \
  --keep_going \
  --test_output=errors \
  //...
