#!/usr/bin/env python3
"""Confere o registro de issues: índice = disco, rodapé = contagem, VERIFIED exige smoke."""
import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

STATUS_RE = re.compile(r"\*\*Status:\*\*\s*([A-Z]+)")
ROW_RE = re.compile(r"^\|\s*(ISSUE-\d+)\s*\|")
FOOTER_RE = re.compile(
    r"Total:\s*(\d+) issues \((\d+) OPEN, (\d+) FIXED[^,]*, (\d+) VERIFIED, (\d+) CLOSED\)"
)
SMOKE_RE = re.compile(r"\*\*Smoke:\*\*\s*(\S+?RECORD\.md)\s*;\s*m[óo]dulo:\s*(.+?)\s*$")
SECTION_STATE = {"open": "OPEN", "fixed": "FIXED", "verified": "VERIFIED", "closed": "CLOSED"}
STATES = ["OPEN", "FIXED", "VERIFIED", "CLOSED"]


def read_index(index_path):
    """Devolve {id: estado da seção} e a lista de ids repetidos."""
    rows, dups, section = {}, [], None
    for line in index_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = SECTION_STATE.get(line[3:].split()[0].lower())
            continue
        m = ROW_RE.match(line)
        if m and section:
            if m.group(1) in rows:
                dups.append(m.group(1))
            rows[m.group(1)] = section
    return rows, dups


def module_result(record_path, module):
    """Devolve None se toda linha do módulo traz pass (uma por classe de chip); senão a mensagem de erro."""
    if not record_path.is_file():
        return f"RECORD.md ausente: {record_path}"
    found = []
    for line in record_path.read_text(encoding="utf-8").splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [c.strip().casefold() for c in line.strip().strip("|").split("|")]
        if module.casefold() in cells:
            found.append(cells)
    if not found:
        return f"módulo {module} sem linha em {record_path}"
    if any("pass" not in cells for cells in found):
        return f"módulo {module} não aparece como pass em todas as classes de {record_path}"
    return None


def check(issues_dir, repo_root):
    """Devolve a lista de erros; lista vazia significa gate verde."""
    errors = []
    index_path = issues_dir / "INDEX.md"
    rows, dups = read_index(index_path)
    for iid in dups:
        errors.append(f"{iid}: linha duplicada no INDEX")

    disk = {}
    for f in sorted(issues_dir.glob("ISSUE-*.md")):
        iid = f.stem
        text = f.read_text(encoding="utf-8")
        m = STATUS_RE.search(text)
        if not m:
            errors.append(f"{iid}: sem campo **Status:**")
            continue
        status = m.group(1)
        disk[iid] = status
        if iid not in rows:
            errors.append(f"{iid}: arquivo sem linha no INDEX (órfã)")
            continue
        if rows[iid] != status:
            errors.append(f"{iid}: status {status} mas o INDEX lista na seção {rows[iid]}")
        if status == "VERIFIED":
            sm = SMOKE_RE.search(text)
            if not sm:
                errors.append(f"{iid}: VERIFIED sem evidência de smoke (linha **Smoke:** com RECORD.md e módulo)")
            else:
                err = module_result(repo_root / sm.group(1), sm.group(2))
                if err:
                    errors.append(f"{iid}: VERIFIED sem smoke válido: {err}")

    for iid in sorted(set(rows) - set(disk)):
        errors.append(f"{iid}: linha no INDEX sem arquivo em disco")

    counts = {s: sum(1 for v in rows.values() if v == s) for s in STATES}
    footer = FOOTER_RE.search(index_path.read_text(encoding="utf-8"))
    if not footer:
        errors.append("rodapé Total ausente ou fora do formato")
    else:
        declared = dict(zip(["total", *STATES], map(int, footer.groups())))
        expected = {"total": sum(counts.values()), **counts}
        if declared != expected:
            errors.append(f"rodapé diverge do índice: rodapé {declared} vs índice {expected}")
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--issues-dir", type=Path, default=REPO / ".app-work" / "issues")
    parser.add_argument("--repo-root", type=Path, default=REPO)
    args = parser.parse_args(argv)
    errors = check(args.issues_dir, args.repo_root)
    for e in errors:
        print(f"ERRO {e}")
    if errors:
        print(f"{len(errors)} erro(s)")
        return 1
    print("OK: índice = disco, rodapé conferido, VERIFIED com smoke")
    return 0


if __name__ == "__main__":
    sys.exit(main())
