#!/usr/bin/env python3
"""Registro assinado do ensaio de fumaca e barreira de OBL-01..13 do legado-provas.

Leitura e validacao apenas: nao rede, nao escreve resultados de obrigacoes.
Uso: smoke_record.py --check .app-work/smoke/<versao>/RECORD.md
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SMOKE_DIR = ROOT / ".app-work/smoke"
ROADMAP = ROOT / ".app-work/archive/roadmap/legado-provas-teste/roadmap.json"
GATE_OBLIGATIONS = [f"OBL-{n:02d}" for n in range(1, 14)]

MODULES = [
    "App Updates",
    "Monitor de sistema",
    "Uninstaller",
    "Cleaner + Tarefas de manutenção",
    "Media tools",
    "Dynamic Island",
    "Mixer por app",
    "Keep Awake",
    "Luz do teclado",
    "Brilho de tela",
    "Kill Process + Port Manager",
    "Captura de tela + OCR",
]
MAINTENANCE = [
    "flushDNS",
    "freePurgeable",
    "purgeInactiveMemory",
    "rebuildLaunchServices",
    "rebuildSpotlight",
    "cleanupHomebrew",
]
CHIP_SECTIONS = ["## Chip mapeado", "## Chip fora do mapa"]
CHIP_MAPPED = "mapped"
CHIP_UNMAPPED = "unmapped"
CHIP_GENERIC = "generic"
CHECKBOXES = ["Localização", "Caracterização"]
FORBIDDEN = re.compile(r"(?i)e-?mail|serial|agend|schedul")
ROW = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$", re.M)


def _refuse(message):
    raise SystemExit(message)


def default_record(version):
    return SMOKE_DIR / version / "RECORD.md"


def _read(path):
    try:
        return Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        _refuse(f"Registro de ensaio ausente: {path}. Copie scripts/release/fixtures/RECORD_template.md e assine.")
    except UnicodeDecodeError:
        _refuse(f"Registro de ensaio não é UTF-8: {path}.")


def _field(text, label):
    match = re.search(rf"^\*\*{re.escape(label)}:\*\*[ \t]*(.*)$", text, re.M)
    return match.group(1).strip() if match else ""


def _chip(body):
    match = re.search(r"^\*\*Chip:\*\*[ \t]*(.*)$", body, re.M)
    return match.group(1).strip() if match else ""


def _apple_silicon_generation(brand):
    prefix = "Apple M"
    if not brand.startswith(prefix):
        return None
    remainder = brand[len(prefix):]
    if not remainder:
        return None
    first = remainder[0]
    if first not in "12345":
        return None
    after = remainder[1:]
    if after and after[0] != " ":
        return None
    return int(first)


def chip_platform(brand):
    """Espelha TemperatureSensorSelector.platform(brandString:) para a classe do ensaio."""
    name = (brand or "").strip()
    if name == "Apple A18 Pro":
        return CHIP_GENERIC
    if _apple_silicon_generation(name) is not None:
        return CHIP_MAPPED
    if name.startswith("Apple "):
        return CHIP_UNMAPPED
    return CHIP_GENERIC


def _section(text, heading):
    match = re.search(rf"^{re.escape(heading)}[ \t]*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return match.group(1) if match else None


def _rows(body):
    rows = []
    for name, result in ROW.findall(body):
        if name in {"Módulo", "Tarefa"} or set(name) <= set("-: "):
            continue
        rows.append((name, result))
    return rows


def _check_section(heading, body):
    rows = _rows(body)
    names = [name for name, _ in rows]
    if len(names) != len(set(names)):
        _refuse(f"{heading}: linha duplicada.")
    unknown = [name for name in names if name not in MODULES and name not in MAINTENANCE]
    if unknown:
        _refuse(f"{heading}: linha não prevista no escopo: {unknown[0]}.")
    results = dict(rows)
    for module in MODULES:
        if module not in results:
            _refuse(f"{heading}: módulo ausente no registro: {module}.")
    for task in MAINTENANCE:
        if task not in results:
            _refuse(f"{heading}: tarefa de manutenção ausente: {task}.")
    failed = [name for name, result in rows if result != "pass"]
    if failed:
        _refuse(f"{heading}: {failed[0]} não está como pass; a versão não é aprovada.")


def validate(record_path, expected_version):
    text = _read(record_path)
    if FORBIDDEN.search(text):
        _refuse("Registro contém campo proibido (e-mail, serial ou agendamento).")
    if _field(text, "Versão") != expected_version:
        _refuse(f"Registro não corresponde à versão {expected_version}.")
    signer = _field(text, "Operador (assinatura)")
    if not signer or signer == "pendente":
        _refuse("Registro sem assinatura do operador.")
    chips = []
    for heading in CHIP_SECTIONS:
        body = _section(text, heading)
        if body is None:
            _refuse(f"Registro sem a seção '{heading}'.")
        chip = _chip(body)
        if not chip or chip == "pendente":
            _refuse(f"{heading}: linha 'Chip:' ausente ou vazia.")
        expected = CHIP_MAPPED if heading == "## Chip mapeado" else CHIP_UNMAPPED
        if chip_platform(chip) != expected:
            if heading == "## Chip mapeado":
                _refuse(f"{heading}: chip {chip} não é família M1–M5 mapeada.")
            else:
                _refuse(f"{heading}: chip {chip} não está fora do mapa de gerações (unmappedAppleSilicon).")
        chips.append(chip)
        _check_section(heading, body)
    if chips[0].casefold() == chips[1].casefold():
        _refuse("As duas classes de chip têm o mesmo valor em 'Chip:'; a segunda classe não foi ensaiada.")
    for label in CHECKBOXES:
        if not re.search(rf"^- \[x\] {label}", text, re.M):
            _refuse(f"Verificação '{label}' não marcada no registro.")


def require_release_obligations(roadmap_path=ROADMAP):
    try:
        roadmap = json.loads(Path(roadmap_path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        _refuse(f"legado-provas ilegível: {roadmap_path}.")
    results = {}
    for slice_ in roadmap.get("slices", []):
        for obligation in slice_.get("obligations", []):
            results[obligation.get("id")] = obligation.get("result")
    missing = [oid for oid in GATE_OBLIGATIONS if oid not in results]
    if missing:
        _refuse(f"legado-provas sem obrigações do gate: {', '.join(missing)}.")
    open_ = [oid for oid in GATE_OBLIGATIONS if results[oid] != "PASSED"]
    if open_:
        _refuse(f"Obrigações do legado-provas abertas: {', '.join(open_)}. Publicação bloqueada.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", type=Path, required=True, help=".app-work/smoke/<versao>/RECORD.md")
    args = parser.parse_args(argv)
    version = args.check.parent.name
    validate(args.check, version)
    require_release_obligations()
    print(f"Registro {version} válido.")


if __name__ == "__main__":
    sys.exit(main())
