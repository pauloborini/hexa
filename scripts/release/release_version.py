#!/usr/bin/env python3
"""Fonte única da versão pública e separação dos metadados numéricos do macOS."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
VERSION_FILE = ROOT / "Sources/Hexa/Resources/ReleaseVersion.txt"
VERSION_PATTERN = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-beta(?:\.[1-9]\d*)?)?")

def bundle_version(version):
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError("Versão inválida: use X.Y.Z, X.Y.Z-beta ou X.Y.Z-beta.N")
    return version.split("-", 1)[0]

def current_version():
    value = VERSION_FILE.read_text().strip()
    bundle_version(value)
    return value

if __name__ == "__main__":
    print(current_version())
