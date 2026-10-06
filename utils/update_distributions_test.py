import copy
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

    def test_retains_versions_outside_refresh_selection(self):
        # Previously catalogued versions need not still appear in the API.
        old_versions = ["2.9.0", "2.40.4", "2.41.0"]
        existing = update.collect_mold_catalogue(
            [release(v) for v in old_versions], old_versions,
        )
        releases = [release(v) for v in ["3.0.0", "2.42.1", "2.42.0", "2.40.5"]]
        # Advancing BCR must not remove its previously catalogued version either.
        versions = update.selected_mold_versions(releases, "2.40.5")
        catalogue = update.collect_mold_catalogue(releases, versions, existing)
        self.assertEqual(
            list(catalogue["mold"]),
            ["3.0.0", "2.42.1", "2.42.0", "2.41.0", "2.40.5", "2.40.4", "2.9.0"],
        )
        for version in old_versions:
            self.assertEqual(catalogue["mold"][version], existing["mold"][version])

    def test_retains_other_linkers_and_platforms_without_mutating_input(self):
        existing = update.collect_mold_catalogue([release("3.0.0")], ["3.0.0"])
        entry = copy.deepcopy(existing["mold"]["3.0.0"]["linux-x86_64"])
        existing["mold"]["3.0.0"]["linux-riscv64"] = entry
        existing["other_linker"] = {"1.0.0": {"linux-x86_64": entry}}
        original = copy.deepcopy(existing)
        releases = [release("3.0.0", "b" * 64)]
        catalogue = update.collect_mold_catalogue(releases, ["3.0.0"], existing)
        self.assertEqual(catalogue["other_linker"], original["other_linker"])
        self.assertEqual(catalogue["mold"]["3.0.0"]["linux-riscv64"], entry)
        self.assertEqual(catalogue["mold"]["3.0.0"]["linux-x86_64"]["sha256"], "b" * 64)
        self.assertEqual(existing, original)
        self.assertEqual(
            update.render_linkers_jsonc(catalogue),
            update.render_linkers_jsonc(update.collect_mold_catalogue(releases, ["3.0.0"], catalogue)),
        )

    def test_existing_catalogue_does_not_mask_missing_digest(self):
        existing = update.collect_mold_catalogue([release("2.42.1")], ["2.42.1"])
        with self.assertRaisesRegex(RuntimeError, "lacks a GitHub SHA-256"):
            update.collect_mold_catalogue([release("2.42.1", "")], ["2.42.1"], existing)

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
