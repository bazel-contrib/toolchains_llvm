"""Exercise the real extra-distributions helper without network downloads."""

import ast
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class ExtraDistributionsTest(unittest.TestCase):
    def run_helper(self, version, assets):
        with tempfile.TemporaryDirectory(
            prefix="llvm-extra-distributions-", dir=os.environ.get("TEST_TMPDIR")
        ) as directory:
            root = Path(directory)
            metadata = root / "metadata.json"
            metadata.write_text(json.dumps({"assets": assets}))
            curl = root / "curl"
            # Only the release metadata request is allowed. Any attempt to
            # download an archive fails instead of reaching the network.
            curl.write_text("""#!/bin/sh
for arg in "$@"; do url="$arg"; done
if [ "$url" != "$LLVM_TEST_RELEASE_URL" ]; then
  echo "Unexpected download: $url" >&2
  exit 1
fi
cat "$LLVM_TEST_RELEASE_JSON"
""")
            curl.chmod(0o755)
            env = dict(os.environ)
            env.pop("GITHUB_TOKEN", None)
            env.update({
                "PATH": str(root) + os.pathsep + os.environ.get("PATH", os.defpath),
                "LLVM_TEST_RELEASE_URL": "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-" + version,
                "LLVM_TEST_RELEASE_JSON": str(metadata),
            })
            return subprocess.run(
                ["bash", str(Path(__file__).with_name("extra_distributions.sh")),
                 "-t", str(root / "output"), "-v", version],
                env=env, capture_output=True, text=True, check=False, timeout=30,
            )

    def assert_archives(self, version, prefix, suffixes):
        names = [prefix + ".tar." + suffix for suffix in suffixes]
        expected = {name: format(index, "064x") for index, name in enumerate(names, start=1)}
        assets = [
            {"name": name, "digest": "sha256:" + digest,
             "browser_download_url": "https://example.invalid/" + name}
            for name, digest in expected.items()
        ]
        # Neither source archives nor binaries for another version belong in
        # the output, even when GitHub attaches them to the requested release.
        assets.extend({"name": name} for name in [
            "llvm-project-" + version + ".src.tar.xz",
            "LLVM-99.0.0-Linux-X64.tar.xz",
        ])
        result = self.run_helper(version, assets)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(ast.literal_eval("{\n" + result.stdout + "\n}"), expected)

    def test_keeps_all_compressions_and_checksums(self):
        for version in ["23.1.2", "23.1.0-rc3"]:
            for prefix in [
                "LLVM-" + version + "-Linux-X64",
                "clang+llvm-" + version + "-x86_64-linux-gnu",
            ]:
                with self.subTest(version=version, prefix=prefix):
                    self.assert_archives(version, prefix, ["xz", "zst", "gz"])

    def test_keeps_single_compression(self):
        for suffix in ["xz", "zst", "gz"]:
            with self.subTest(suffix=suffix):
                self.assert_archives("23.1.2", "LLVM-23.1.2-Linux-X64", [suffix])

    def test_no_matching_archives_fails(self):
        result = self.run_helper("23.1.2", [])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no matching tarball assets found", result.stderr)


if __name__ == "__main__":
    unittest.main()
