import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("update", Path(__file__).with_name("update_distributions.py"))
update = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update)


def release(version, digest="a" * 64):
    return {"tag_name": "v" + version, "draft": False, "prerelease": False, "assets": [
        {"name": f"mold-{version}-{arch}-linux.tar.gz", "digest": "sha256:" + digest, "browser_download_url": f"https://example/{version}/{arch}"}
        for arch in ["aarch64", "x86_64"]
    ]}


class UpdateTest(unittest.TestCase):
    def test_llvm_catalogue_keeps_all_compressions_and_checksums(self):
        expected = {
            "LLVM-23.1.2-Linux-X64.tar." + suffix: format(index, "064x")
            for index, suffix in enumerate(["xz", "zst", "gz"], start=1)
        }
        releases = [{
            "tag_name": "llvmorg-23.1.2",
            "draft": False,
            "assets": [
                {"name": name, "digest": "sha256:" + digest}
                for name, digest in expected.items()
            ],
        }]
        entries = update.collect_llvm_entries(releases, {})
        self.assertEqual(
            {name: digest for _, name, digest in entries},
            expected,
        )

    def test_latest_three_plus_bcr(self):
        releases = [release(v) for v in ["2.42.1", "2.42.0", "2.41.0", "2.40.4"]]
        self.assertEqual(update.selected_mold_versions(releases, "2.40.4"), ["2.42.1", "2.42.0", "2.41.0", "2.40.4"])

    def test_bcr_is_deduplicated(self):
        releases = [release(v) for v in ["2.42.1", "2.42.0", "2.41.0"]]
        self.assertEqual(update.selected_mold_versions(releases, "2.41.0"), ["2.42.1", "2.42.0", "2.41.0"])

    def test_digest_is_required(self):
        with self.assertRaisesRegex(RuntimeError, "lacks a GitHub SHA-256"):
            update.collect_mold_catalogue([release("2.42.1", "")], ["2.42.1"])

    def test_catalogue_platforms_and_determinism(self):
        catalogue = update.collect_mold_catalogue([release("2.42.1")], ["2.42.1"])
        self.assertEqual(set(catalogue["mold"]["2.42.1"]), {"linux-aarch64", "linux-x86_64"})
        self.assertEqual(
            catalogue["mold"]["2.42.1"]["linux-x86_64"]["linker_features"],
            ["start_end_lib"],
        )
        self.assertEqual(update.render_linkers_jsonc(catalogue), update.render_linkers_jsonc(catalogue))


if __name__ == "__main__":
    unittest.main()
