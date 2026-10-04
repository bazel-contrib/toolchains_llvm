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

"""Exercise the actual Darwin wrapper without downloading an LLVM toolchain."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest


WRAPPER_TEMPLATE = Path(__file__).resolve().parents[1] / "toolchain/osx_cc_wrapper.sh.tpl"


class DarwinLtoLibraryTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="darwin-lto-wrapper-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        # Exercise both shell whitespace and the comma separator used by -Wl.
        self.distribution = self.root / "external/llvm toolchain,23"
        self.wrapper = self.root / "external/config/bin/cc_wrapper.sh"
        self.wrapper.parent.mkdir(parents=True)
        (self.distribution / "bin").mkdir(parents=True)
        (self.distribution / "lib").mkdir()
        self.library = self.distribution / "lib/libLTO.dylib"
        self.library.touch()
        self.write_wrapper("external/llvm toolchain,23/")
        clang = self.distribution / "bin/clang"
        clang.write_text(
            "#!" + sys.executable + "\n"
            "import json, pathlib, shlex, sys\n"
            "args = []\n"
            "for arg in sys.argv[1:]:\n"
            "    if arg.startswith('@') and pathlib.Path(arg[1:]).is_file():\n"
            "        args.extend(shlex.split(pathlib.Path(arg[1:]).read_text()))\n"
            "    else:\n"
            "        args.append(arg)\n"
            "print(json.dumps(args))\n"
        )
        clang.chmod(0o755)

    def write_wrapper(self, prefix):
        self.wrapper.write_text(
            WRAPPER_TEMPLATE.read_text().replace("%{toolchain_path_prefix}", prefix)
        )

    def invoke(self, args, response_file=False):
        if response_file:
            response = self.root / "args.rsp"
            response.write_text("\n".join(shlex.quote(arg) for arg in args) + "\n")
            args = ["@args.rsp"]
        result = subprocess.run(
            ["bash", str(self.wrapper.relative_to(self.root)), *args],
            cwd=self.root,
            env=os.environ.copy(),
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return json.loads(result.stdout)

    def assert_matching_library(self, args):
        self.assertEqual(
            args[-4:],
            ["-Xlinker", "-lto_library", "-Xlinker", str(self.library)],
        )

    def test_native_link_uses_absolute_matching_library(self):
        for lto in ([], ["-flto=thin"], ["-flto"]):
            with self.subTest(lto=lto):
                args = ["--ld-path=/usr/bin/ld", *lto, "input.o"]
                actual = self.invoke(args)
                self.assertEqual(actual[:-4], args)
                self.assert_matching_library(actual)

    def test_response_file_native_link(self):
        args = ["--ld-path=/usr/bin/ld", "-flto=thin", "input.o"]
        actual = self.invoke(args, response_file=True)
        self.assertEqual(actual[:-4], args)
        self.assert_matching_library(actual)

    def test_absolute_toolchain_prefix(self):
        self.write_wrapper(str(self.distribution) + "/")
        self.assert_matching_library(self.invoke(["input.o"]))

    def test_missing_library_does_not_add_a_nonexistent_input(self):
        self.library.unlink()
        self.assertEqual(self.invoke(["input.o"]), ["input.o"])

    def test_compile_only_actions_are_unchanged(self):
        for flag in ("-c", "-S", "-E", "-fsyntax-only", "-M", "-MM", "--analyze", "-emit-ast"):
            for response_file in (False, True):
                with self.subTest(flag=flag, response_file=response_file):
                    args = [flag, "input.cc"]
                    self.assertEqual(self.invoke(args, response_file), args)

    def test_lld_does_not_receive_an_override(self):
        for flag in ("--ld-path=ld64.lld", "--ld-path=/tools/ld64.lld", "-fuse-ld=lld"):
            for response_file in (False, True):
                with self.subTest(flag=flag, response_file=response_file):
                    actual = self.invoke([flag, "input.o"], response_file)
                    self.assertNotIn("-lto_library", actual)

    def test_effective_linker_selection(self):
        # --ld-path takes precedence over -fuse-ld; the last --ld-path wins.
        self.assert_matching_library(self.invoke([
            "-fuse-ld=lld", "--ld-path=/usr/bin/ld", "input.o",
        ]))
        self.assert_matching_library(self.invoke([
            "--ld-path=/tools/ld64.lld", "--ld-path=/usr/bin/ld", "input.o",
        ]))
        actual = self.invoke([
            "--ld-path=/usr/bin/ld", "--ld-path=/tools/ld64.lld", "input.o",
        ])
        self.assertNotIn("-lto_library", actual)

    def test_explicit_library_is_preserved(self):
        choices = (
            ["-Wl,-lto_library,/custom/libLTO.dylib"],
            ["-Wl,-lto_library", "-Wl,/custom/libLTO.dylib"],
            ["-Wl,-dead_strip,-lto_library,/custom/libLTO.dylib"],
            ["-Xlinker", "-lto_library", "-Xlinker", "/custom/libLTO.dylib"],
        )
        for choice in choices:
            for response_file in (False, True):
                with self.subTest(choice=choice, response_file=response_file):
                    args = [*choice, "input.o"]
                    self.assertEqual(self.invoke(args, response_file), args)

    def test_forwarded_compile_flags_do_not_disable_linking(self):
        for forwarding in ("-Xlinker", "-Xclang"):
            with self.subTest(forwarding=forwarding):
                self.assert_matching_library(self.invoke([forwarding, "-S", "input.o"]))

    def test_darwin_targets(self):
        for target in ("aarch64-apple-macosx", "x86_64-apple-darwin", "aarch64-unknown-darwin"):
            with self.subTest(target=target):
                self.assert_matching_library(self.invoke(["--target=" + target, "input.o"]))

    def test_non_darwin_targets_do_not_receive_apple_flags(self):
        for target in ("aarch64-unknown-linux-gnu", "wasm32-unknown-unknown"):
            for selection in (["--target=" + target], ["-target", target], ["--target", target]):
                for response_file in (False, True):
                    with self.subTest(selection=selection, response_file=response_file):
                        args = [*selection, "input.o"]
                        self.assertEqual(self.invoke(args, response_file), args)


if __name__ == "__main__":
    unittest.main()
