#!/usr/bin/env python3
"""Proveniência do build de release; detecta alterações concorrentes nas fontes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
def snapshot():
    files = [ROOT / "Package.swift"] + sorted(p for p in (ROOT / "Sources").rglob("*") if p.is_file() and p.name != ".DS_Store")
    value = hashlib.sha256()
    for path in files:
        value.update(str(path.relative_to(ROOT)).encode())
        value.update(hashlib.sha256(path.read_bytes()).digest())
    def git(*args): return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()
    return {"sha": git("rev-parse", "HEAD"), "dirty": bool(git("status", "--porcelain")), "sourceHash": value.hexdigest()}
if __name__ == "__main__":
    current = snapshot()
    if len(sys.argv) == 2:
        before = json.loads(Path(sys.argv[1]).read_text())
        if current["sha"] != before["sha"] or current["sourceHash"] != before["sourceHash"]:
            raise SystemExit("Fontes/commit mudaram durante o build; recompilar antes de empacotar.")
    else: print(json.dumps(current, indent=2))
