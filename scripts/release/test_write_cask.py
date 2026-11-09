#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""O cask só consome SHA e URL do recibo de distribuição, nunca de prévia."""
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import write_cask

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VERSION = "0.1.0"
DMG_NAME = f"hexa-{VERSION}-arm64.dmg"
DOWNLOAD = f"https://github.com/pauloborini/hexa/releases/download/v#{{version}}/hexa-#{{version}}-arm64.dmg"
TAP = "brew tap pauloborini/hexa https://github.com/pauloborini/hexa"


def digest(data):
    return hashlib.sha256(data).hexdigest()


class WriteCaskTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.folder = self.tmp / "receipt"
        self.folder.mkdir()
        self.output = self.tmp / "hexa.rb"
        self.payload = b"dmg-bytes-for-cask"
        self.sha = digest(self.payload)
        (self.folder / DMG_NAME).write_bytes(self.payload)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write_receipt(self, **overrides):
        manifest = {
            "version": VERSION,
            "preview": False,
            "dirty": False,
            "notarized": True,
            "dmg": DMG_NAME,
            "app": "hexa.app",
        }
        manifest.update(overrides)
        (self.folder / "release.json").write_text(json.dumps(manifest) + "\n")
        dmg = self.folder / manifest["dmg"]
        if dmg.is_file():
            (self.folder / "SHA256SUMS").write_text(f"{digest(dmg.read_bytes())}  {manifest['dmg']}\n")

    def render(self):
        return write_cask.write_cask(self.folder, self.output)

    def test_default_output_is_repo_cask(self):
        self.assertEqual(write_cask.DEFAULT_OUTPUT, ROOT / "Casks" / "hexa.rb")

    def test_writes_sha_and_github_download_url(self):
        self.write_receipt()
        text = self.render()
        self.assertIn(f'  version "{VERSION}"', text)
        self.assertIn(f'  sha256 "{self.sha}"', text)
        self.assertIn(f'  url "{DOWNLOAD}"', text)
        self.assertIn("  auto_updates false", text)
        self.assertIn(TAP, text)
        self.assertEqual(self.output.read_text(), text)
        self.assertNotIn("PREVIEW", text)

    def test_preview_receipt_does_not_write_cask(self):
        self.write_receipt(preview=True, dmg="hexa-PREVIEW-arm64.dmg")
        preview = self.folder / "hexa-PREVIEW-arm64.dmg"
        preview.write_bytes(self.payload)
        (self.folder / "SHA256SUMS").write_text(f"{digest(self.payload)}  hexa-PREVIEW-arm64.dmg\n")
        with self.assertRaises(SystemExit):
            self.render()
        self.assertFalse(self.output.exists())

    def test_unnotarized_receipt_does_not_write_cask(self):
        self.write_receipt(notarized=False)
        with self.assertRaises(SystemExit):
            self.render()
        self.assertFalse(self.output.exists())

    def test_dirty_receipt_does_not_write_cask(self):
        self.write_receipt(dirty=True)
        with self.assertRaises(SystemExit):
            self.render()
        self.assertFalse(self.output.exists())

    def test_checksum_mismatch_does_not_write_cask(self):
        self.write_receipt()
        (self.folder / "SHA256SUMS").write_text(f"{'0' * 64}  {DMG_NAME}\n")
        with self.assertRaises(SystemExit):
            self.render()
        self.assertFalse(self.output.exists())

    def test_wrong_dmg_name_does_not_write_cask(self):
        self.write_receipt(dmg="other.dmg")
        (self.folder / "other.dmg").write_bytes(self.payload)
        (self.folder / "SHA256SUMS").write_text(f"{digest(self.payload)}  other.dmg\n")
        with self.assertRaises(SystemExit):
            self.render()
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
