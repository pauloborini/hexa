#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Sequencer do rascunho: DMG depois appcast.xml; recusa latest incompleto."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import publish
from prepare_dmg import digest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RELEASES = ROOT / ".app-work" / "releases"
VERSION = "0.1.0"
DMG_NAME = f"hexa-{VERSION}-arm64.dmg"
TAG = f"v{VERSION}"
REPO = "pauloborini/hexa"
SHA = "deadbeef" * 5
STABLE_FEED = "https://github.com/pauloborini/hexa/releases/latest/download/appcast.xml"


class FakeGh:
    def __init__(self, assets=None):
        self.calls = []
        self.assets = list(assets or [])

    def __call__(self, argv):
        argv = [str(a) for a in argv]
        self.calls.append(argv)
        if argv[:3] == ["gh", "release", "create"]:
            for item in argv[4:]:
                if item.startswith("-"):
                    break
                self.assets.append(Path(item).name)
            return ""
        if argv[:3] == ["gh", "release", "upload"]:
            for item in argv[4:]:
                if item.startswith("-"):
                    continue
                self.assets.append(Path(item).name)
            return ""
        if argv[:3] == ["gh", "release", "view"]:
            return json.dumps({"assets": [{"name": name} for name in self.assets]})
        if argv[:3] == ["gh", "release", "edit"]:
            return ""
        raise AssertionError(argv)

    def create_call(self):
        for call in self.calls:
            if call[:3] == ["gh", "release", "create"]:
                return call
        return None

    def upload_calls(self):
        return [call for call in self.calls if call[:3] == ["gh", "release", "upload"]]

    def edit_calls(self):
        return [call for call in self.calls if call[:3] == ["gh", "release", "edit"]]

    def undraft_calls(self):
        found = []
        for call in self.calls:
            joined = " ".join(call)
            if "--draft=false" in call or "--draft=false" in joined:
                found.append(call)
            if call[:3] == ["gh", "release", "publish"] or "release publish" in joined:
                found.append(call)
        return found


def names_in(argv):
    names = []
    for item in argv[4:]:
        if item.startswith("-"):
            break
        names.append(Path(item).name)
    return names


class PublishSequencerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hexa-publish-test-"))
        self.dmg = self.tmp / DMG_NAME
        self.dmg.write_bytes(b"fake-dmg")
        self.sums = self.tmp / "SHA256SUMS"
        self.receipt = self.tmp / "release.json"
        self.receipt.write_text(json.dumps({"version": VERSION, "dmg": DMG_NAME}), encoding="utf-8")
        self.sums.write_text(
            f"{digest(self.dmg)}  {DMG_NAME}\n{digest(self.receipt)}  release.json\n",
            encoding="utf-8",
        )
        self.notes = self.tmp / "notes.md"
        self.notes.write_text("notas", encoding="utf-8")
        self.appcast = self.tmp / "appcast.xml"
        self.appcast.write_text("<rss/>", encoding="utf-8")
        self.manifest = {
            "version": VERSION,
            "preview": False,
            "dirty": False,
            "notarized": True,
            "dmg": DMG_NAME,
            "sha": SHA,
            "app": "hexa.app",
        }
        self.gh = FakeGh()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def extras(self):
        return [self.sums, self.receipt]

    def test_draft_attaches_appcast_after_dmg(self):
        tag = publish.run_draft_sequence(
            self.manifest,
            self.tmp,
            self.appcast,
            repo=REPO,
            notes=self.notes,
            run_gh=self.gh,
        )
        self.assertEqual(tag, TAG)
        create = self.gh.create_call()
        uploads = self.gh.upload_calls()
        self.assertIsNotNone(create)
        self.assertEqual(len(uploads), 1)
        self.assertLess(self.gh.calls.index(create), self.gh.calls.index(uploads[0]))
        self.assertIn("--draft", create)
        self.assertIn(DMG_NAME, names_in(create))
        self.assertNotIn("appcast.xml", names_in(create))
        self.assertTrue(any(Path(item).name == "appcast.xml" for item in uploads[0]))
        self.assertNotIn("--draft=false", [item for call in self.gh.calls for item in call])

    def test_refuses_publish_without_both_assets(self):
        only_dmg = FakeGh(assets=[DMG_NAME, "SHA256SUMS", "release.json"])
        with self.assertRaises(SystemExit):
            publish.publish_release(TAG, DMG_NAME, repo=REPO, run_gh=only_dmg)
        self.assertEqual(only_dmg.undraft_calls(), [])
        self.assertEqual(only_dmg.edit_calls(), [])

        only_feed = FakeGh(assets=["appcast.xml", "SHA256SUMS", "release.json"])
        with self.assertRaises(SystemExit):
            publish.publish_release(TAG, DMG_NAME, repo=REPO, run_gh=only_feed)
        self.assertEqual(only_feed.undraft_calls(), [])
        self.assertEqual(only_feed.edit_calls(), [])

    def test_upload_asset_named_appcast_xml(self):
        publish.attach_appcast(TAG, self.appcast, repo=REPO, run_gh=self.gh)
        upload = self.gh.upload_calls()[0]
        self.assertEqual(Path(upload[4]).name, "appcast.xml")
        self.assertEqual(upload[3], TAG)
        self.assertTrue(STABLE_FEED.endswith("/" + Path(upload[4]).name))

        other = self.tmp / "sparkle.xml"
        other.write_text("<rss/>", encoding="utf-8")
        before = list(self.gh.calls)
        with self.assertRaises(SystemExit):
            publish.attach_appcast(TAG, other, repo=REPO, run_gh=self.gh)
        self.assertEqual(self.gh.calls, before)
        versioned = self.tmp / "appcast-v0.1.0.xml"
        versioned.write_text("<rss/>", encoding="utf-8")
        with self.assertRaises(SystemExit):
            publish.attach_appcast(TAG, versioned, repo=REPO, run_gh=self.gh)
        self.assertEqual(self.gh.calls, before)

    def test_default_run_gh_invokes_gh(self):
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="ok\n", stderr="")
        with mock.patch.object(publish.subprocess, "run", return_value=completed) as run:
            out = publish.default_run_gh(["gh", "release", "view", TAG, "--json", "assets"])
        self.assertEqual(out, "ok\n")
        self.assertEqual(run.call_args[0][0][0], "gh")
        self.assertEqual(run.call_args[0][0][1:3], ["release", "view"])


class PublishMainTests(unittest.TestCase):
    def setUp(self):
        RELEASES.mkdir(parents=True, exist_ok=True)
        self.folder = RELEASES / f"_publish_test_{Path(tempfile.mkdtemp()).name}"
        self.folder.mkdir(parents=True, exist_ok=True)
        self.dmg = self.folder / DMG_NAME
        self.dmg.write_bytes(b"fake-dmg-main")
        self.app = self.folder / "hexa.app"
        self.app.write_text("app", encoding="utf-8")
        self.receipt = self.folder / "release.json"
        self.receipt.write_text(
            json.dumps(
                {
                    "version": VERSION,
                    "preview": False,
                    "dirty": False,
                    "notarized": True,
                    "dmg": DMG_NAME,
                    "sha": SHA,
                    "app": "hexa.app",
                }
            ),
            encoding="utf-8",
        )
        (self.folder / "SHA256SUMS").write_text(
            f"{digest(self.dmg)}  {DMG_NAME}\n{digest(self.receipt)}  release.json\n",
            encoding="utf-8",
        )
        self.notes = self.folder / "notes.md"
        self.notes.write_text("notas de teste", encoding="utf-8")
        self.appcast = self.folder / "appcast.xml"
        self.appcast.write_text("<rss/>", encoding="utf-8")
        self.gh = FakeGh()

    def tearDown(self):
        shutil.rmtree(self.folder, ignore_errors=True)

    def fake_run(self, *args, capture=False):
        argv = [str(a) for a in args]
        if argv[:3] == ["git", "status", "--porcelain"]:
            return ""
        if argv[:3] == ["git", "branch", "--show-current"]:
            return "main"
        if argv[:2] == ["git", "rev-parse"] and argv[2] == "HEAD":
            return SHA
        if argv[:2] == ["git", "rev-parse"]:
            return SHA
        if argv[:2] == ["xcrun", "stapler"]:
            return None
        raise AssertionError(argv)

    def run_main(self, extra=None, gh=None):
        argv = [
            str(self.folder),
            "--repo",
            REPO,
            "--notes",
            str(self.notes),
            "--smoke-approved",
            "--appcast",
            str(self.appcast),
        ]
        if extra:
            argv.extend(extra)
        publish.main(
            argv,
            run_gh=gh or self.gh,
            run=self.fake_run,
            validate_smoke=lambda path, version: None,
        )

    def test_default_cli_does_not_undraft(self):
        self.run_main()
        self.assertIsNotNone(self.gh.create_call())
        self.assertEqual(len(self.gh.upload_calls()), 1)
        self.assertEqual(self.gh.undraft_calls(), [])
        self.assertEqual(self.gh.edit_calls(), [])
        for call in self.gh.calls:
            self.assertNotIn("--draft=false", call)
            self.assertNotEqual(call[:3], ["gh", "release", "publish"])

    def test_publish_flag_undrafts_when_assets_complete(self):
        self.run_main(extra=["--publish"])
        self.assertIsNotNone(self.gh.create_call())
        self.assertEqual(len(self.gh.upload_calls()), 1)
        self.assertEqual(
            self.gh.undraft_calls(),
            [["gh", "release", "edit", TAG, "--repo", REPO, "--draft=false"]],
        )


if __name__ == "__main__":
    unittest.main()
