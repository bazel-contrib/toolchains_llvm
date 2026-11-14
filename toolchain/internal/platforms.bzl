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

"""Platform constants with no external loads, usable during WORKSPACE setup."""

SUPPORTED_TARGETS = [
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("linux", "armv7"),
    ("linux", "riscv64"),
    ("darwin", "x86_64"),
    ("darwin", "aarch64"),
    ("none", "riscv32"),
    ("none", "riscv64"),
    ("none", "wasm32"),
    ("none", "wasm64"),
    ("none", "x86_64"),
    ("wasip1", "wasm32"),
    ("wasip1", "wasm64"),
]

SUPPORTED_PLATFORM_KEYS = [
    arch if os == "none" and arch in ["wasm32", "wasm64"] else "{}-{}".format(os, arch)
    for os, arch in SUPPORTED_TARGETS
]
