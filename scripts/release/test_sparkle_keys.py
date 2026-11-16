#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Backup, verificação e restore EdDSA sem plaintext no repositório."""
import io
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sparkle_keys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PUBLIC = "EdDSAPublicKeyForRestoreTest"
SIGNATURE = 'sparkle:edSignature="RestoreTestSignature" length="16"\n'


class FakeSparkle:
    def __init__(self, public=PUBLIC, export_body=None):
        self.public = public
        self.export_body = export_body or f"export-body-{id(self)}"
        self.calls = []
        self.imported = False
        self.keychain_has_key = False

    def __call__(self, argv):
        argv = list(argv)
        self.calls.append(argv)
        if "-s" in argv:
            raise AssertionError("generate_keys -s é recusado neste wrapper")
        tool, *args = argv
        if tool == "generate_keys":
            if args == ["-p"]:
                if self.imported or self.keychain_has_key:
                    return self.public + "\n"
                raise sparkle_keys.SparkleCommandError(argv, 1)
            if args == []:
                self.keychain_has_key = True
                return ""
            if args[:1] == ["-x"]:
                if Path(args[1]).exists():
                    raise AssertionError("generate_keys -x exige um destino ainda inexistente")
                Path(args[1]).write_text(self.export_body)
                return ""
            if args[:1] == ["-f"]:
                self.imported = True
                self.keychain_has_key = True
                return ""
            raise AssertionError(argv)
        if tool == "sign_update":
            if not (self.imported or self.keychain_has_key):
                return "unsigned\n"
            return SIGNATURE
        raise AssertionError(argv)

    def generated_default(self):
        return any(call == ["generate_keys"] for call in self.calls)

    def export_path(self):
        for call in self.calls:
            if call[:2] == ["generate_keys", "-x"]:
                return Path(call[2])
        return None


class SparkleKeysTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hexa-sparkle-test-"))
        self.public_path = self.tmp / "sparkle_ed_public.txt"
        self.image = self.tmp / "backup.dmg"
        self.password = "test-backup-password"
        self.fake = FakeSparkle()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def captured_export(self):
        buffer = io.StringIO()
        with mock.patch("sys.stdout", buffer):
            sparkle_keys.export_backup(self.image, self.password, run_sparkle=self.fake)
        return buffer.getvalue()

    def test_password_can_be_read_from_stdin(self):
        with mock.patch("sys.stdin", io.StringIO("stdin-backup-password\n")):
            self.assertEqual(sparkle_keys._read_password(Path("-")), "stdin-backup-password")

    def test_restore_matches_recorded_public_key(self):
        self.public_path.write_text(PUBLIC + "\n")
        self.captured_export()
        output = sparkle_keys.restore_backup(
            self.image,
            self.password,
            public_key_path=self.public_path,
            run_sparkle=self.fake,
        )
        self.assertIn("sparkle:edSignature", output)
        self.assertTrue(any(call[:2] == ["generate_keys", "-f"] for call in self.fake.calls))
        self.assertTrue(any(call[:1] == ["sign_update"] for call in self.fake.calls))
        self.assertEqual(sparkle_keys.public_key(self.public_path), PUBLIC)

        self.public_path.write_text("OtherPublicKey\n")
        before = list(self.fake.calls)
        with self.assertRaises(SystemExit) as raised:
            sparkle_keys.restore_backup(
                self.image,
                self.password,
                public_key_path=self.public_path,
                run_sparkle=self.fake,
            )
        self.assertIn("diverge", str(raised.exception))
        self.assertEqual(
            [call for call in self.fake.calls[len(before):] if call[:1] == ["sign_update"]],
            [],
        )

    def test_verify_backup_matches_current_private_key(self):
        self.captured_export()
        self.assertIsNone(
            sparkle_keys.verify_backup(self.image, self.password, run_sparkle=self.fake)
        )
        export_calls = [call for call in self.fake.calls if call[:2] == ["generate_keys", "-x"]]
        self.assertEqual(len(export_calls), 2)
        for call in export_calls:
            self.assertFalse(Path(call[2]).exists())

    def test_loss_refuses_new_key(self):
        self.public_path.write_text(PUBLIC + "\n")
        with self.assertRaises(SystemExit) as raised:
            sparkle_keys.init_keys(public_key_path=self.public_path, run_sparkle=self.fake)
        self.assertIn("Suspenda o canal", str(raised.exception))
        self.assertIn("DMG", str(raised.exception))
        self.assertFalse(self.fake.generated_default())
        with self.assertRaises(SystemExit):
            sparkle_keys.refuse_loss_regenerate()

    def test_export_deletes_plaintext(self):
        leaked = HERE / "backup-test.dmg"
        try:
            with self.assertRaises(SystemExit) as raised:
                sparkle_keys.export_backup(leaked, self.password, run_sparkle=self.fake)
            self.assertIn("repositório", str(raised.exception))
            self.assertFalse(leaked.exists())
        finally:
            leaked.unlink(missing_ok=True)

        stdout = self.captured_export()
        x_path = self.fake.export_path()
        self.assertIsNotNone(x_path)
        self.assertFalse(x_path.exists())
        self.assertTrue(self.image.is_file())
        self.assertFalse(sparkle_keys.inside_repo(self.image))
        self.assertNotIn(self.fake.export_body, stdout)
        self.assertNotIn(self.fake.export_body, self.public_path.read_text() if self.public_path.exists() else "")
        for path in HERE.iterdir():
            if not path.is_file() or path.suffix in {".py", ".pyc"}:
                continue
            text = path.read_text(errors="ignore")
            self.assertNotIn("-----BEGIN " + "PRIVATE KEY-----", text, path.name)
            self.assertNotIn("-----BEGIN OPENSSH PRIVATE KEY-----", text, path.name)
            self.assertNotIn(self.fake.export_body, text, path.name)

        blocker = self.tmp / "blocker-file"
        blocker.write_text("x")
        broken = blocker / "hexa-sparkle-backup.dmg"
        failing = FakeSparkle(export_body=f"export-body-fail-{id(self)}")
        with self.assertRaises(SystemExit):
            sparkle_keys.export_backup(broken, self.password, run_sparkle=failing)
        fail_path = failing.export_path()
        self.assertIsNotNone(fail_path)
        self.assertFalse(fail_path.exists())
        self.assertFalse(broken.exists())

    def test_export_refuses_to_overwrite_existing_backup(self):
        self.image.write_bytes(b"existing backup")
        with self.assertRaises(SystemExit) as raised:
            sparkle_keys.export_backup(self.image, self.password, run_sparkle=self.fake)
        self.assertIn("não será sobrescrita", str(raised.exception))
        self.assertEqual(self.image.read_bytes(), b"existing backup")
        self.assertIsNone(self.fake.export_path())

    def test_default_run_sparkle_invokes_sparkle_binary(self):
        bindir = Path(tempfile.mkdtemp(prefix="hexa-sparkle-bin-"))
        try:
            binary = bindir / "generate_keys"
            binary.write_text("#!/bin/sh\n")
            completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="PUB\n", stderr="")
            with mock.patch.dict(os.environ, {"SPARKLE_BIN": str(bindir)}):
                with mock.patch.object(sparkle_keys.subprocess, "run", return_value=completed) as run:
                    out = sparkle_keys.default_run_sparkle(["generate_keys", "-p"])
            self.assertEqual(out, "PUB\n")
            self.assertEqual(run.call_args[0][0][0], str(binary))
            self.assertEqual(run.call_args[0][0][1:], ["-p"])
        finally:
            shutil.rmtree(bindir, ignore_errors=True)

    def test_init_records_public_key_on_first_use(self):
        printed = sparkle_keys.init_keys(public_key_path=self.public_path, run_sparkle=self.fake)
        self.assertEqual(printed, PUBLIC)
        self.assertTrue(self.fake.generated_default())
        self.assertEqual(self.public_path.read_text(), PUBLIC + "\n")


if __name__ == "__main__":
    unittest.main()
