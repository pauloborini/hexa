#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Appcast local: enclosure versionada, assinatura e fail-closed sem mutar cask/DMG."""
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import feed_prepare
import write_cask

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CASK = ROOT / "Casks" / "hexa.rb"
VERSION = "0.1.0"
DMG_NAME = f"hexa-{VERSION}-arm64.dmg"
VERSIONED_URL = (
    f"https://github.com/pauloborini/hexa/releases/download/v{VERSION}/{DMG_NAME}"
)
LATEST_URL = f"https://github.com/pauloborini/hexa/releases/latest/download/{DMG_NAME}"
SIGNATURE = "TestEdSignatureNotASecret"
SIGN_OUTPUT = f'sparkle:edSignature="{SIGNATURE}" length="16"\n'
EXPORT_BODY = "sparkle-x-export-body-MUST-NOT-APPEAR"


def unsigned_appcast(url):
    return f"""<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>hexa</title>
        <item>
            <title>{VERSION}</title>
            <sparkle:version>1</sparkle:version>
            <sparkle:shortVersionString>{VERSION}</sparkle:shortVersionString>
            <enclosure url="{url}" length="16" type="application/octet-stream"/>
        </item>
    </channel>
</rss>
"""


class FakeSparkle:
    def __init__(
        self,
        fail_generate=False,
        fail_sign=False,
        enclosure_url=None,
        include_export=False,
        already_signed=False,
    ):
        self.fail_generate = fail_generate
        self.fail_sign = fail_sign
        self.enclosure_url = enclosure_url
        self.include_export = include_export
        self.already_signed = already_signed
        self.calls = []

    def __call__(self, argv):
        argv = list(argv)
        self.calls.append(argv)
        if "-s" in argv:
            raise AssertionError("Sparkle -s é recusado")
        tool, *args = argv
        if tool == "generate_appcast":
            if self.fail_generate:
                raise feed_prepare.SparkleCommandError(argv, 1, "", "generate_appcast failed")
            output = self._option(args, "-o")
            prefix = self._option(args, "--download-url-prefix")
            archives = Path(args[-1])
            dmg = archives / DMG_NAME
            url = self.enclosure_url
            if url is None:
                url = f"{prefix}{dmg.name}" if prefix else VERSIONED_URL
            xml = unsigned_appcast(url)
            if self.already_signed:
                xml = xml.replace(
                    "type=\"application/octet-stream\"",
                    f'type="application/octet-stream" sparkle:edSignature="{SIGNATURE}"',
                )
            if self.include_export:
                xml = xml.replace(
                    "</channel>",
                    (
                        "<description>-----BEGIN PRIVATE KEY-----\n"
                        f"{EXPORT_BODY}\n"
                        "-----END PRIVATE KEY-----</description></channel>"
                    ),
                )
            Path(output).write_text(xml)
            return ""
        if tool == "sign_update":
            if self.fail_sign:
                raise feed_prepare.SparkleCommandError(argv, 1, "", "sign_update failed")
            return SIGN_OUTPUT
        raise AssertionError(argv)

    def _option(self, args, flag):
        if flag in args:
            return args[args.index(flag) + 1]
        return None

    def generate_argv(self):
        for call in self.calls:
            if call[:1] == ["generate_appcast"]:
                return call
        return None


class FeedPrepareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hexa-feed-test-"))
        self.workdir = self.tmp / "work"
        self.workdir.mkdir()
        self.dmg = self.tmp / DMG_NAME
        self.dmg.write_bytes(b"fake-dmg-bytes")
        self.cask_before = CASK.read_text()
        self.fake = FakeSparkle()

    def tearDown(self):
        self.assertEqual(CASK.read_text(), self.cask_before)
        shutil.rmtree(self.tmp, ignore_errors=True)

    def prepare(self, fake=None, **kwargs):
        return feed_prepare.prepare_appcast(
            self.dmg,
            VERSION,
            self.workdir,
            run_sparkle=fake or self.fake,
            **kwargs,
        )

    def enclosure_url_from(self, xml):
        match = re.search(r'<enclosure\b[^>]*\burl="([^"]+)"', xml)
        self.assertIsNotNone(match)
        return match.group(1)

    def test_enclosure_is_versioned_not_latest(self):
        self.assertEqual(feed_prepare.enclosure_url(VERSION), VERSIONED_URL)
        self.assertEqual(feed_prepare.enclosure_url(VERSION), write_cask.DOWNLOAD_URL.replace("#{version}", VERSION))
        self.assertNotIn("/releases/latest/download/", feed_prepare.enclosure_url(VERSION))

        result = self.prepare()
        self.assertTrue(result.channel_ready)
        self.assertEqual(result.appcast_path.name, "appcast.xml")
        xml = result.appcast_path.read_text()
        url = self.enclosure_url_from(xml)
        self.assertEqual(url, VERSIONED_URL)
        self.assertNotIn("/releases/latest/download/", url)
        self.assertIn(f'sparkle:edSignature="{SIGNATURE}"', xml)
        self.assertNotIn(EXPORT_BODY, xml)
        argv = self.fake.generate_argv()
        self.assertIsNotNone(argv)
        self.assertIn("--maximum-deltas", argv)
        self.assertEqual(argv[argv.index("--maximum-deltas") + 1], "0")
        self.assertIn("-o", argv)
        self.assertTrue(argv[argv.index("-o") + 1].endswith("appcast.xml"))
        prefix = argv[argv.index("--download-url-prefix") + 1]
        self.assertEqual(prefix, f"https://github.com/pauloborini/hexa/releases/download/v{VERSION}/")
        self.assertNotIn("/releases/latest/download/", prefix)

        latest = FakeSparkle(enclosure_url=LATEST_URL)
        latest_result = self.prepare(fake=latest)
        self.assertFalse(latest_result.channel_ready)
        if latest_result.appcast_path and latest_result.appcast_path.is_file():
            latest_xml = latest_result.appcast_path.read_text()
            latest_url = self.enclosure_url_from(latest_xml)
            self.assertTrue(
                "/releases/latest/download/" in latest_url and latest_url.endswith(".dmg")
            )
            self.assertFalse(feed_prepare.channel_ready(latest_result.appcast_path, VERSION))

        exported = FakeSparkle(include_export=True, already_signed=True)
        exported_result = self.prepare(fake=exported)
        self.assertFalse(exported_result.channel_ready)
        self.assertIn(EXPORT_BODY, exported_result.appcast_path.read_text())

    def test_unsigned_item_is_not_channel_ready(self):
        xml = unsigned_appcast(VERSIONED_URL)
        kept = feed_prepare.require_signature(xml, self.dmg, inject=False, run_sparkle=self.fake)
        self.assertNotIn("sparkle:edSignature", kept)
        appcast = self.workdir / "appcast.xml"
        appcast.write_text(kept)
        self.assertFalse(feed_prepare.channel_ready(appcast, VERSION))
        self.assertFalse(any(call[:1] == ["sign_update"] for call in self.fake.calls))

    def test_tool_failure_leaves_cask_and_dmg_untouched(self):
        original_name = self.dmg.name
        original_bytes = self.dmg.read_bytes()
        failed = FakeSparkle(fail_generate=True)
        result = self.prepare(fake=failed)
        self.assertFalse(result.channel_ready)
        self.assertFalse(feed_prepare.channel_ready(result.appcast_path, VERSION))
        self.assertEqual(CASK.read_text(), self.cask_before)
        self.assertIn("auto_updates false", self.cask_before)
        self.assertEqual(self.dmg.name, original_name)
        self.assertEqual(self.dmg.read_bytes(), original_bytes)
        self.assertTrue(self.dmg.is_file())

        sign_fail = FakeSparkle(fail_sign=True)
        sign_result = self.prepare(fake=sign_fail)
        self.assertFalse(sign_result.channel_ready)
        self.assertEqual(CASK.read_text(), self.cask_before)
        self.assertEqual(self.dmg.name, original_name)

    def test_sign_update_emits_ed_signature(self):
        result = self.prepare()
        self.assertTrue(any(call[:1] == ["sign_update"] for call in self.fake.calls))
        xml = result.appcast_path.read_text()
        self.assertIn(f'sparkle:edSignature="{SIGNATURE}"', xml)
        self.assertTrue(result.channel_ready)

        already = FakeSparkle(already_signed=True)
        second = self.prepare(fake=already)
        self.assertTrue(second.channel_ready)
        self.assertFalse(any(call[:1] == ["sign_update"] for call in already.calls))

    def test_current_dmg_opens_in_generate_appcast(self):
        dmg = os.environ.get("HEXA_CURRENT_DMG", "").strip()
        bindir = os.environ.get("SPARKLE_BIN", "").strip()
        if not dmg or not Path(dmg).is_file():
            self.skipTest("HEXA_CURRENT_DMG ausente; prova live do generate_appcast não executada")
        if not bindir or not (Path(bindir) / "generate_appcast").is_file():
            self.skipTest("SPARKLE_BIN/generate_appcast ausente; prova live não executada")
        live_dir = Path(tempfile.mkdtemp(prefix="hexa-feed-live-"))
        try:
            with mock.patch.dict(os.environ, {"SPARKLE_BIN": bindir}):
                result = feed_prepare.prepare_appcast(
                    Path(dmg),
                    VERSION,
                    live_dir,
                    inject_signature=False,
                )
            appcast = live_dir / "appcast.xml"
            self.assertTrue(appcast.is_file(), msg=result.error)
            xml = appcast.read_text()
            self.assertIn("<item>", xml)
            self.assertIn(DMG_NAME, xml)
            self.assertNotIn("SUFeedURL", xml)
        finally:
            shutil.rmtree(live_dir, ignore_errors=True)

    def test_default_run_sparkle_invokes_sparkle_binary(self):
        bindir = Path(tempfile.mkdtemp(prefix="hexa-sparkle-bin-"))
        try:
            binary = bindir / "generate_appcast"
            binary.write_text("#!/bin/sh\n")
            completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
            with mock.patch.dict(os.environ, {"SPARKLE_BIN": str(bindir)}):
                with mock.patch.object(feed_prepare.subprocess, "run", return_value=completed) as run:
                    feed_prepare.default_run_sparkle(
                        ["generate_appcast", "--maximum-deltas", "0", "-o", "appcast.xml", str(self.workdir)]
                    )
            self.assertEqual(run.call_args[0][0][0], str(binary))
            self.assertEqual(run.call_args[0][0][1], "--maximum-deltas")
        finally:
            shutil.rmtree(bindir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
