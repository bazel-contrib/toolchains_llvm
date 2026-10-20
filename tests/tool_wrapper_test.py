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

"""Exercise shared tool-wrapper behavior without downloading an LLVM toolchain."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


TOOLCHAIN = Path(__file__).resolve().parents[1] / "toolchain"
TEMPLATES = ("cc_wrapper.sh.tpl", "osx_cc_wrapper.sh.tpl")


class ToolWrapperTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="llvm-tool-wrapper-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve() / "paths with spaces"

    def write_wrapper(self, template, layout, tool, name):
        cwd = self.root / template / layout
        base = cwd / "external" if layout == "execroot" else cwd
        wrapper = base / "config/bin" / name
        executable = base / "llvm/bin" / tool
        wrapper.parent.mkdir(parents=True, exist_ok=True)
        executable.parent.mkdir(parents=True, exist_ok=True)
        prefix = (str(executable.parent.parent) + "/"
                  if layout == "absolute-prefix" else "external/llvm/")
        wrapper.write_text(
            (TOOLCHAIN / template).read_text()
            .replace("%{toolchain_path_prefix}", prefix)
            .replace("%{tool_name}", tool)
        )
        executable.write_text(
            "#!" + sys.executable + "\n"
            "import json, os, pathlib, sys\n"
            "response_files = {a[1:]: pathlib.Path(a[1:]).read_text()\n"
            "                  for a in sys.argv[1:] if a.startswith('@')}\n"
            "print(json.dumps({'tool': pathlib.Path(sys.argv[0]).name,\n"
            "                  'args': sys.argv[1:], 'response_files': response_files}))\n"
            "sys.exit(int(os.environ.get('FAKE_TOOL_EXIT', '0')))\n"
        )
        executable.chmod(0o755)
        return cwd, wrapper

    def invoke(self, cwd, wrapper, args=(), absolute=False, exit_code=0):
        path = wrapper if absolute else wrapper.relative_to(cwd)
        return subprocess.run(
            ["bash", str(path), *args],
            cwd=cwd,
            env={**os.environ, "FAKE_TOOL_EXIT": str(exit_code)},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_auxiliary_tool_paths_and_aliases(self):
        for template in TEMPLATES:
            for layout in ("execroot", "runfiles", "absolute-prefix"):
                for tool, name in (("llvm-ar", "llvm-ar"), ("llvm-libtool-darwin", "libtool")):
                    cwd, wrapper = self.write_wrapper(template, layout, tool, name)
                    for absolute in (False, True):
                        with self.subTest(template=template, layout=layout, tool=tool, absolute=absolute):
                            result = self.invoke(cwd, wrapper, absolute=absolute)
                            self.assertEqual(result.returncode, 0, result.stderr)
                            self.assertEqual(json.loads(result.stdout)["tool"], tool)

    def test_auxiliary_arguments_and_exit_status_are_unchanged(self):
        for template in TEMPLATES:
            cwd, wrapper = self.write_wrapper(template, "execroot", "llvm-ar", "llvm-ar")
            response = cwd / "arguments.rsp"
            response.write_text("input with spaces.o\n")
            # These compiler-looking arguments must not trigger compiler handling.
            args = ["argument with spaces", "", "*.o", "@arguments.rsp",
                    "--toolchains_llvm-unsupported-msan=darwin", "--ld-path=bin/linkers/ld",
                    "-fsanitize-ignorelist=keep-this-path", "-o", "output.h.processed"]
            for exit_code in (0, 23):
                with self.subTest(template=template, exit_code=exit_code):
                    result = self.invoke(cwd, wrapper, args, absolute=True, exit_code=exit_code)
                    self.assertEqual(result.returncode, exit_code, result.stderr)
                    record = json.loads(result.stdout)
                    self.assertEqual(record["args"], args)
                    self.assertEqual(record["response_files"], {"arguments.rsp": response.read_text()})
                    self.assertFalse((cwd / "output.h.processed").exists())

    def test_clang_still_processes_response_files_and_headers(self):
        for template in TEMPLATES:
            with self.subTest(template=template):
                cwd, wrapper = self.write_wrapper(template, "execroot", "clang", "cc_wrapper.sh")
                response = cwd / "compile.rsp"
                response.write_text("-c\nsource.cc\n-o\nheader.h.processed\n")
                result = self.invoke(cwd, wrapper, ["@compile.rsp"])
                self.assertEqual(result.returncode, 0, result.stderr)
                record = json.loads(result.stdout)
                self.assertEqual(record["tool"], "clang")
                self.assertEqual(list(record["response_files"].values()), [response.read_text()])
                self.assertNotEqual(record["args"], ["@compile.rsp"])
                self.assertFalse(Path(record["args"][0][1:]).exists())
                self.assertTrue((cwd / "header.h.processed").is_file())


if __name__ == "__main__":
    unittest.main()
