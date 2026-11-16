#!/usr/bin/env python3
"""Testes do gate de smoke em uma máquina macOS arm64."""
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import smoke_record

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TEMPLATE = HERE / "fixtures" / "RECORD_template.md"
SWIFT_EFFECTS = ROOT / "Tests/hexaTests/EffectorCharacterizationTests.swift"
VERSION = "9.9.9"
TMP_ROOT = ROOT / ".app-work" / "tmp"


class SmokeRecordValidateTests(unittest.TestCase):
    def setUp(self):
        TMP_ROOT.mkdir(parents=True, exist_ok=True)
        self.tmp = Path(tempfile.mkdtemp(prefix="smoke-record-test-", dir=TMP_ROOT))
        self.evidence_paths = {}
        for criterion in smoke_record.CRITERIA:
            evidence = self.tmp / f"{criterion}.txt"
            evidence.write_text(f"evidence {criterion}\n", encoding="utf-8")
            self.evidence_paths[criterion] = evidence

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def valid_text(self, version=VERSION):
        lines = [
            "# Registro de smoke de release",
            "",
            f"**Versão:** {version}",
            "**Arquitetura:** arm64",
            "**Máquina:** Apple Silicon arm64 Mac",
            "**Operador (atestação):** Operador do repositório",
        ]
        for criterion in smoke_record.CRITERIA:
            evidence = self.evidence_paths[criterion].relative_to(ROOT)
            lines.extend(
                [
                    "",
                    f"## {criterion} - validação do rollout",
                    "**Resultado:** pass",
                    f"**Evidência:** {evidence}",
                ]
            )
        return "\n".join(lines) + "\n"

    def write_record(self, text):
        path = self.tmp / "RECORD.md"
        path.write_text(text, encoding="utf-8")
        return path

    def refuses(self, text, version=VERSION):
        path = self.write_record(text)
        with self.assertRaises(SystemExit):
            smoke_record.validate(path, version)

    def test_single_arm64_machine_and_r1_to_r3_pass(self):
        path = self.write_record(self.valid_text())
        smoke_record.validate(path, VERSION)

    def test_missing_record_refuses_before_gh(self):
        folder = ROOT / ".app-work" / "releases" / f"_smoke_test_{self.tmp.name}"
        folder.mkdir(parents=True, exist_ok=True)
        notes = self.tmp / "notes.md"
        notes.write_text("nota de teste", encoding="utf-8")
        (folder / "release.json").write_text('{"version":"9.9.8"}', encoding="utf-8")
        missing = self.tmp / "missing-record.md"
        try:
            result = subprocess.run(
                [
                    sys.executable,
                    str(HERE / "publish.py"),
                    str(folder),
                    "--repo",
                    "x/y",
                    "--notes",
                    str(notes),
                    "--smoke-approved",
                    "--smoke-record",
                    str(missing),
                ],
                capture_output=True,
                text=True,
                cwd=ROOT,
            )
        finally:
            shutil.rmtree(folder, ignore_errors=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Registro de smoke ausente", result.stderr)

    def test_required_fields_and_criteria_refuse_incomplete_record(self):
        base = self.valid_text()
        path = self.write_record(base)
        smoke_record.validate(path, VERSION)

        cases = {
            "architecture": base.replace("**Arquitetura:** arm64", "**Arquitetura:** x86_64"),
            "machine": base.replace("**Máquina:** Apple Silicon arm64 Mac", "**Máquina:** pendente"),
            "operator": base.replace("**Operador (atestação):** Operador do repositório", "**Operador (atestação):** pendente"),
            "missing R2": re.sub(r"^## R2 .*?(?=^## |\Z)", "", base, flags=re.M | re.S),
            "duplicate R1": base + "\n## R1 - repetido\n**Resultado:** pass\n**Evidência:** .app-work/no-such-evidence.txt\n",
            "failed R3": base.replace("**Resultado:** pass", "**Resultado:** fail", 3),
            "missing evidence": base.replace("**Evidência:** .app-work", "**Evidência:** pendente", 1),
            "wrong version": base,
            "truncated": base[: len(base) // 2],
        }
        for name, text in cases.items():
            with self.subTest(case=name):
                if name == "wrong version":
                    self.refuses(text, version="9.9.8")
                else:
                    self.refuses(text)

    def test_evidence_must_exist_inside_repository(self):
        base = self.valid_text()
        missing = base.replace(
            str(self.evidence_paths["R1"].relative_to(ROOT)),
            ".app-work/tmp/no-such-evidence.txt",
        )
        self.refuses(missing)
        outside = base.replace(
            str(self.evidence_paths["R1"].relative_to(ROOT)),
            "../../../../etc/passwd",
        )
        self.refuses(outside)

    def test_record_rejects_private_fields_and_has_no_external_gate(self):
        self.refuses(self.valid_text() + "\n**Serial:** 123\n")
        source = (HERE / "smoke_record.py").read_text(encoding="utf-8")
        publisher = (HERE / "publish.py").read_text(encoding="utf-8")
        for token in ("urllib", "socket", "http.client", "requests", "urlopen", "roadmap.json", "OBL-"):
            self.assertNotIn(token, source)
            self.assertNotIn(token, publisher)
        template = TEMPLATE.read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"(?i)e-?mail|serial|agend|schedul", template))
        self.assertNotIn("URLSession", SWIFT_EFFECTS.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
