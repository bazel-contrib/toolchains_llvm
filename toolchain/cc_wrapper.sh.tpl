#!/bin/sh
#
# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SCRIPT_DIR=$(dirname "$0")

# Search for `bash` on the system, and then execute cc_wrapper_inner.sh with
# it.

# Attempt #1: /bin/bash -- present on FHS-compliant systems, but notably absent
# on others, including NixOS.
if /bin/bash true; then
  /bin/bash "${SCRIPT_DIR}"/cc_wrapper_inner.sh "$@"
  exit $?
fi

# Attempt #2: /usr/bin/env bash -- /usr/bin/env is required by POSIX, but some
# callers to the LLVM toolchain, such as rules_rust, clear $PATH and leave
# nothing for /usr/bin/env to search for.
# if /usr/bin/env bash true; then
#     /usr/bin/env bash "${SCRIPT_DIR}"/cc_wrapper_inner.sh "$@"
#     exit $?
# fi

# Attempt #3: Try `command -v`.
if command -v bash; then
  CMD=$(command -v bash)
  "${CMD}" "${SCRIPT_DIR}"/cc_wrapper_inner.sh "$@"
  exit $?
fi

echo >&2 'Failed to find bash at /bin/bash or in PATH.'
exit 1
