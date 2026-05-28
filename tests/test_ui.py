import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def load_json(name: str) -> dict:
    return json.loads((REPO_ROOT / name).read_text(encoding="utf-8"))


def repo_path(relative_path: str) -> Path:
    return REPO_ROOT / Path(relative_path.replace("/", "\\"))


class LivingMetaUiContracts(unittest.TestCase):
    def test_inventory_entries_are_portable_and_exist(self) -> None:
        inventory = load_json("inventory.json")

        self.assertGreater(len(inventory["items"]), 0)
        for item in inventory["items"]:
            self.assertNotIn("C:\\", item["launchUrl"])
            self.assertNotIn("D:\\", item["launchUrl"])
            self.assertNotIn("file:///", item["launchUrl"])
            self.assertTrue(repo_path(item["launchUrl"]).is_file(), item["launchUrl"])
            self.assertTrue(item["folderUrl"].startswith("library.html?"), item["folderUrl"])
            self.assertTrue(repo_path(item["shortcutPath"]).is_file(), item["shortcutPath"])

    def test_library_manifest_entries_are_portable_and_exist(self) -> None:
        manifest = load_json("library-manifest.json")

        self.assertGreater(len(manifest["items"]), 0)
        for item in manifest["items"]:
            self.assertNotIn("C:\\", item["copyPath"])
            self.assertNotIn("D:\\", item["copyPath"])
            self.assertNotIn("file:///", item["copyPath"])
            self.assertTrue(repo_path(item["copyPath"]).is_file(), item["copyPath"])
            self.assertTrue(repo_path(item["folderPath"]).is_dir(), item["folderPath"])

    def test_generated_assets_match_portable_contract(self) -> None:
        library_js = (REPO_ROOT / "library.js").read_text(encoding="utf-8")
        inventory_js = (REPO_ROOT / "inventory.js").read_text(encoding="utf-8")
        index_html = (REPO_ROOT / "index.html").read_text(encoding="utf-8")
        library_html = (REPO_ROOT / "library.html").read_text(encoding="utf-8")
        review_html = (REPO_ROOT / "review.html").read_text(encoding="utf-8")

        self.assertTrue(library_js.startswith("window.LIVING_META_LIBRARY = "))
        self.assertTrue(inventory_js.startswith("window.LIVING_META_INVENTORY = "))

        for text in (library_js, inventory_js, index_html, library_html, review_html):
            self.assertNotIn("C:\\Living metas", text)
            self.assertNotIn("C:\\Projects", text)
            self.assertNotIn("file:///C:/", text)
            self.assertNotIn("file:///D:/", text)


if __name__ == "__main__":
    unittest.main()
