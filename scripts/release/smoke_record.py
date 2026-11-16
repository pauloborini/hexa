#!/usr/bin/env python3
"""Valida o registro de smoke da release em uma máquina macOS arm64."""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SMOKE_DIR = ROOT / ".app-work" / "smoke"
CRITERIA = ("R1", "R2", "R3")
FORBIDDEN = re.compile(r"(?i)e-?mail|serial|agend|schedul")


def _refuse(message):
    raise SystemExit(message)


def default_record(version):
    return SMOKE_DIR / version / "RECORD.md"


def _read(path):
    try:
        return Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        _refuse("Registro de smoke ausente. Copie scripts/release/fixtures/RECORD_template.md e preencha-o.")
    except UnicodeDecodeError:
        _refuse("Registro de smoke não é UTF-8.")


def _field(text, label):
    match = re.search(rf"^\*\*{re.escape(label)}:\*\*[ \t]*(.*)$", text, re.M)
    return match.group(1).strip() if match else ""


def _section(text, heading):
    pattern = rf"^## {re.escape(heading)}(?:[ \t]+[^\n]*)?[ \t]*$(.*?)(?=^## |\Z)"
    matches = list(re.finditer(pattern, text, re.M | re.S))
    if len(matches) > 1:
        _refuse(f"Registro contém a seção {heading} mais de uma vez.")
    return matches[0].group(1) if matches else None


def _evidence_path(value, criterion):
    path = Path(value)
    if path.is_absolute():
        _refuse(f"Evidência de {criterion} precisa usar caminho relativo ao repositório.")
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT.resolve()):
        _refuse(f"Evidência de {criterion} aponta para fora do repositório.")
    if not resolved.is_file():
        _refuse(f"Evidência de {criterion} ausente.")


def validate(record_path, expected_version):
    path = Path(record_path).resolve()
    if not path.is_relative_to(ROOT.resolve()):
        _refuse("Registro de smoke precisa ficar dentro do repositório.")
    text = _read(path)
    if FORBIDDEN.search(text):
        _refuse("Registro contém campo proibido (e-mail, serial ou agendamento).")
    if _field(text, "Versão") != expected_version:
        _refuse(f"Registro não corresponde à versão {expected_version}.")
    if _field(text, "Arquitetura") != "arm64":
        _refuse("Registro precisa confirmar a arquitetura arm64.")
    if not _field(text, "Máquina") or _field(text, "Máquina").casefold() == "pendente":
        _refuse("Registro sem identificação da máquina de smoke.")
    operator = _field(text, "Operador (atestação)")
    if not operator or operator.casefold() == "pendente":
        _refuse("Registro sem atestação do operador.")
    for criterion in CRITERIA:
        body = _section(text, criterion)
        if body is None:
            _refuse(f"Registro sem a seção {criterion}.")
        if _field(body, "Resultado") != "pass":
            _refuse(f"{criterion} não está como pass.")
        evidence = _field(body, "Evidência")
        if not evidence:
            _refuse(f"Evidência de {criterion} ausente.")
        _evidence_path(evidence, criterion)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", type=Path, required=True, help=".app-work/smoke/<versao>/RECORD.md")
    args = parser.parse_args(argv)
    version = args.check.parent.name
    validate(args.check, version)
    print(f"Registro {version} válido em uma máquina arm64.")


if __name__ == "__main__":
    sys.exit(main())
