#!/bin/bash
# Copyright 2026 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

binary="$1"
expected_sdk="$(xcrun --show-sdk-version --sdk macosx)"
actual_sdk="$(xcrun vtool -show-build "${binary}" | awk '$1 == "sdk" { print $2; exit }')"

if [[ -z "${actual_sdk}" ]]; then
  echo >&2 "Could not read the SDK version from ${binary}"
  exit 1
fi

if [[ "${actual_sdk}" != "${expected_sdk}" ]]; then
  echo >&2 "Expected ${binary} to record macOS SDK ${expected_sdk}, got ${actual_sdk}"
  exit 1
fi
