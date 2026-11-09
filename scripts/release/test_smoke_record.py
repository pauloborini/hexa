#!/usr/bin/env python3
"""Testes da barreira de publicacao: registro assinado e OBL-01..13 do legado-provas."""
import json
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
MAPPED_CHIP = "Apple M5 Pro"
UNMAPPED_CHIP = "Apple M6"


def valid_text(version=VERSION):
    text = TEMPLATE.read_text(encoding="utf-8")
    text = text.replace("| pendente |", "| pass |")
    text = text.replace("**Versão:** pendente", f"**Versão:** {version}")
    text = text.replace("**Operador (assinatura):** pendente", "**Operador (assinatura):** Operador de teste")
    text = text.replace("**Chip:** pendente", f"**Chip:** {MAPPED_CHIP}", 1)
    text = text.replace("**Chip:** pendente", f"**Chip:** {UNMAPPED_CHIP}", 1)
    return text.replace("- [ ]", "- [x]")


def write_record(directory, text):
    path = Path(directory) / "RECORD.md"
    path.write_text(text, encoding="utf-8")
    return path


def roadmap_with(results):
    obligations = [{"id": oid, "result": result} for oid, result in results.items()]
    return {"slices": [{"id": "T1", "obligations": obligations[:1]}, {"id": "T9", "obligations": obligations[1:]}]}


class SmokeRecordValidateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def refuses(self, text, version=VERSION):
        path = write_record(self.tmp, text)
        with self.assertRaises(SystemExit):
            smoke_record.validate(path, version)

    def test_flag_alone_is_not_enough(self):
        # Sem registro, publish.py recusa antes de chegar a gh.
        folder = ROOT / ".app-work" / "releases" / f"_smoke_test_{Path(self.tmp).name}"
        folder.mkdir(parents=True, exist_ok=True)
        notes = Path(self.tmp) / "notes.md"
        notes.write_text("nota de teste", encoding="utf-8")
        (folder / "release.json").write_text(json.dumps({"version": "9.9.8"}), encoding="utf-8")
        try:
            result = subprocess.run(
                [sys.executable, str(HERE / "publish.py"), str(folder), "--repo", "x/y",
                 "--notes", str(notes), "--smoke-approved"],
                capture_output=True, text=True, cwd=ROOT,
            )
        finally:
            shutil.rmtree(folder, ignore_errors=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Registro de ensaio ausente", result.stderr)

    def test_incomplete_record_is_rejected(self):
        base = valid_text()
        path = write_record(self.tmp, base)
        smoke_record.validate(path, VERSION)  # registro completo passa

        self.refuses(re.sub(r"## Chip fora do mapa.*", "", base, flags=re.S))  # classe de chip ausente
        self.refuses(base.replace("| Monitor de sistema | pass |", ""))  # linha de modulo ausente
        self.refuses(base.replace("**Operador (assinatura):** Operador de teste", "**Operador (assinatura):** "))  # assinatura vazia
        self.refuses(base.replace("| flushDNS | pass |", ""), VERSION)  # tarefa manual ausente
        self.refuses(base.replace("- [x] Localização", "- [ ] Localização"))  # checkbox de localizacao
        self.refuses(base.replace("- [x] Caracterização", "- [ ] Caracterização"))  # checkbox de caracterizacao
        self.refuses(base.replace("| Monitor de sistema | pass |", "| Monitor de sistema | fail |", 1))  # linha nao pass
        self.refuses(base + "\n**Agendamento:** sim\n")  # campo de agendamento
        self.refuses(base, version="9.9.8")  # versao divergente
        self.refuses(base[: len(base) // 2])  # registro truncado

    def test_chip_line_is_required_per_section(self):
        base = valid_text()
        self.refuses(base.replace(f"**Chip:** {MAPPED_CHIP}", "**Chip:** pendente", 1))  # chip do mapa pendente
        self.refuses(base.replace(f"**Chip:** {UNMAPPED_CHIP}", "**Chip:**   "))  # chip fora do mapa vazio
        self.refuses(base.replace(f"**Chip:** {UNMAPPED_CHIP}\n", ""))  # linha Chip ausente na secao fora do mapa

    def test_chip_classes_must_differ(self):
        base = valid_text()
        self.refuses(base.replace(f"**Chip:** {UNMAPPED_CHIP}", f"**Chip:** {MAPPED_CHIP}"))  # mesmo valor nas duas secoes

    def test_chip_class_must_match_generation_map(self):
        # F-03: "Chip mapeado" é família M1–M5; "Chip fora do mapa" é unmappedAppleSilicon.
        base = valid_text()
        cases = {
            "M2 mapeado na secao fora do mapa": base.replace(f"**Chip:** {UNMAPPED_CHIP}", "**Chip:** Apple M2"),
            "M7 nao mapeado na secao mapeada": base.replace(f"**Chip:** {MAPPED_CHIP}", "**Chip:** Apple M7", 1),
            "A18 Pro e generic, nao unmapped": base.replace(f"**Chip:** {UNMAPPED_CHIP}", "**Chip:** Apple A18 Pro"),
            "Intel e generic": base.replace(f"**Chip:** {UNMAPPED_CHIP}", "**Chip:** Intel Core i9"),
        }
        for name, text in cases.items():
            with self.subTest(case=name):
                self.refuses(text)

    def test_chip_platform_matches_swift_selector(self):
        cases = {
            "Apple M1": smoke_record.CHIP_MAPPED,
            "Apple M1 Pro": smoke_record.CHIP_MAPPED,
            "Apple M5 Pro": smoke_record.CHIP_MAPPED,
            "Apple M5": smoke_record.CHIP_MAPPED,
            "  Apple M2 Max  ": smoke_record.CHIP_MAPPED,
            "Apple M6": smoke_record.CHIP_UNMAPPED,
            "Apple M6 Pro": smoke_record.CHIP_UNMAPPED,
            "Apple M10": smoke_record.CHIP_UNMAPPED,
            "Apple M5Pro": smoke_record.CHIP_UNMAPPED,
            "Apple T2": smoke_record.CHIP_UNMAPPED,
            "Apple A18 Pro": smoke_record.CHIP_GENERIC,
            "Intel Core i9": smoke_record.CHIP_GENERIC,
        }
        for brand, expected in cases.items():
            with self.subTest(brand=brand):
                self.assertEqual(smoke_record.chip_platform(brand), expected)

    def test_obl_01_13_not_run_refuses(self):
        all_ids = [f"OBL-{n:02d}" for n in range(1, 22)]
        cases = {
            "todos NOT_RUN": {i: "NOT_RUN" for i in all_ids},
            "so OBL-10 NOT_RUN": {i: ("NOT_RUN" if i == "OBL-10" else "PASSED") for i in all_ids},
            "so 14..21 NOT_RUN passa": {i: ("NOT_RUN" if int(i[4:]) >= 14 else "PASSED") for i in all_ids},
        }
        for name, results in cases.items():
            with self.subTest(case=name):
                roadmap = Path(self.tmp) / "roadmap.json"
                roadmap.write_text(json.dumps(roadmap_with(results)), encoding="utf-8")
                if name == "so 14..21 NOT_RUN passa":
                    smoke_record.require_release_obligations(roadmap)
                else:
                    with self.assertRaises(SystemExit):
                        smoke_record.require_release_obligations(roadmap)

    def test_real_archived_roadmap_refuses_today(self):
        with self.assertRaises(SystemExit):
            smoke_record.require_release_obligations()

    def test_validate_has_no_network_and_template_has_no_pii(self):
        source = (HERE / "smoke_record.py").read_text(encoding="utf-8")
        for token in ("urllib", "socket", "http.client", "requests", "urlopen"):
            self.assertNotIn(token, source)
        template = TEMPLATE.read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"(?i)e-?mail|serial|agend|schedul", template))
        self.assertNotIn("URLSession", SWIFT_EFFECTS.read_text(encoding="utf-8"))

    def test_barrier_never_writes_passed_or_calls_legacy_recorder(self):
        writer = re.compile(r'\["result"\]\s*=|"result"\s*:\s*"PASSED"|result\s*=\s*"PASSED"')
        for name in ("smoke_record.py", "publish.py"):
            source = (HERE / name).read_text(encoding="utf-8")
            self.assertIsNone(writer.search(source), name)
            self.assertNotIn("roadmap-test-record", source, name)


if __name__ == "__main__":
    unittest.main()
