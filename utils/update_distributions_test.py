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
        self.assertEqual(update.render_linkers_jsonc(catalogue), update.render_linkers_jsonc(catalogue))


if __name__ == "__main__":
    unittest.main()
