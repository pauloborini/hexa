#!/usr/bin/env python3
"""Testes do gate de issues: índice = disco, rodapé = contagem, VERIFIED exige smoke."""
import tempfile
import unittest
from pathlib import Path

import check_index

REPO = Path(__file__).resolve().parents[2]

SECTIONS = [
    ("Open", "OPEN"),
    ("Fixed (aguardando verificação)", "FIXED"),
    ("Verified", "VERIFIED"),
    ("Closed", "CLOSED"),
]

RECORD = """# Smoke 1.0.0

| Módulo | Resultado |
|---|---|
| Monitor | pass |
| Cleaner | fail |
"""

TWO_CHIP_RECORD = """# Smoke 1.0.0

## Chip mapeado

| Módulo | Resultado |
|---|---|
| Monitor | pass |

## Chip fora do mapa

| Módulo | Resultado |
|---|---|
| Monitor | fail |
"""


def build_tree(root, issues, footer=None, record=True):
    """issues: {id: (status, section_or_None, smoke_module_or_None)}."""
    issues_dir = root / ".app-work" / "issues"
    issues_dir.mkdir(parents=True)
    for iid, (status, _section, module) in issues.items():
        lines = [f"# {iid}: fixture", "", f"- **Status:** {status}, 2026-10-30.", ""]
        if module is not None:
            lines.append(f"- **Smoke:** .app-work/smoke/1.0.0/RECORD.md; módulo: {module}")
        (issues_dir / f"{iid}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    index = ["# INDEX", ""]
    for title, status in SECTIONS:
        index.append(f"## {title}")
        index.append("")
        index.append("| ID | Sev | Feature | Screen | Problem → Expected | Origin | State |")
        index.append("|----|-----|---------|--------|---------------------|--------|--------|")
        for iid, (_s, section, _m) in issues.items():
            if section == status:
                index.append(f"| {iid} | S3 | x | x | x | x | {status} |")
        index.append("")
    counts = {s: sum(1 for v in issues.values() if v[1] == s) for _, s in SECTIONS}
    if footer is None:
        footer = (
            f"Total: {len(issues)} issues ({counts['OPEN']} OPEN, {counts['FIXED']} FIXED "
            f"aguardando verificação, {counts['VERIFIED']} VERIFIED, {counts['CLOSED']} CLOSED)."
        )
    index.append(footer)
    (issues_dir / "INDEX.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    if record:
        rec = root / ".app-work" / "smoke" / "1.0.0"
        rec.mkdir(parents=True)
        (rec / "RECORD.md").write_text(RECORD, encoding="utf-8")
    return issues_dir


class CheckIndexTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def run_check(self, issues_dir):
        return check_index.check(issues_dir, self.root)

    def test_readme_states_verified_requires_smoke_record(self):
        text = (REPO / ".app-work" / "issues" / "README.md").read_text(encoding="utf-8")
        self.assertIn("RECORD.md", text)
        self.assertIn("smoke", text.lower())
        self.assertIn("módulo", text.lower())
        self.assertIn("inspeção de código", text.lower())

    def test_matching_tree_passes(self):
        issues = {
            "ISSUE-001": ("FIXED", "FIXED", None),
            "ISSUE-002": ("VERIFIED", "VERIFIED", "Monitor"),
            "ISSUE-003": ("OPEN", "OPEN", None),
        }
        issues_dir = build_tree(self.root, issues)
        self.assertEqual(self.run_check(issues_dir), [])
        self.assertEqual(check_index.main(["--issues-dir", str(issues_dir), "--repo-root", str(self.root)]), 0)

    def test_orphan_file_fails(self):
        issues = {
            "ISSUE-001": ("FIXED", "FIXED", None),
            "ISSUE-002": ("FIXED", None, None),
        }
        issues_dir = build_tree(self.root, issues, footer="Total: 1 issues (0 OPEN, 1 FIXED aguardando verificação, 0 VERIFIED, 0 CLOSED).")
        errors = self.run_check(issues_dir)
        self.assertTrue(any("ISSUE-002" in e and "órfã" in e for e in errors), errors)
        self.assertEqual(check_index.main(["--issues-dir", str(issues_dir), "--repo-root", str(self.root)]), 1)

    def test_wrong_footer_fails(self):
        issues = {"ISSUE-001": ("FIXED", "FIXED", None), "ISSUE-002": ("OPEN", "OPEN", None)}
        issues_dir = build_tree(self.root, issues, footer="Total: 5 issues (1 OPEN, 1 FIXED aguardando verificação, 0 VERIFIED, 0 CLOSED).")
        errors = self.run_check(issues_dir)
        self.assertTrue(any("rodapé" in e for e in errors), errors)

    def test_verified_without_record_path_fails(self):
        issues = {"ISSUE-002": ("VERIFIED", "VERIFIED", None)}
        issues_dir = build_tree(self.root, issues)
        errors = self.run_check(issues_dir)
        self.assertTrue(any("ISSUE-002" in e and "smoke" in e for e in errors), errors)

    def test_verified_module_not_pass_fails(self):
        issues = {"ISSUE-002": ("VERIFIED", "VERIFIED", "Cleaner")}
        issues_dir = build_tree(self.root, issues)
        errors = self.run_check(issues_dir)
        self.assertTrue(any("ISSUE-002" in e and "pass" in e for e in errors), errors)

    def test_verified_module_failing_in_one_chip_class_fails(self):
        issues = {"ISSUE-002": ("VERIFIED", "VERIFIED", "Monitor")}
        issues_dir = build_tree(self.root, issues)
        (self.root / ".app-work" / "smoke" / "1.0.0" / "RECORD.md").write_text(TWO_CHIP_RECORD, encoding="utf-8")
        errors = self.run_check(issues_dir)
        self.assertTrue(any("ISSUE-002" in e and "pass" in e for e in errors), errors)

    def test_verified_with_record_missing_fails(self):
        issues = {"ISSUE-002": ("VERIFIED", "VERIFIED", "Monitor")}
        issues_dir = build_tree(self.root, issues, record=False)
        errors = self.run_check(issues_dir)
        self.assertTrue(any("RECORD.md" in e for e in errors), errors)

    def test_status_section_mismatch_fails(self):
        issues = {"ISSUE-001": ("FIXED", "OPEN", None)}
        issues_dir = build_tree(self.root, issues)
        errors = self.run_check(issues_dir)
        self.assertTrue(any("ISSUE-001" in e and "seção" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
