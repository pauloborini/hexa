#!/usr/bin/env python3
"""Cria somente o rascunho no GitHub, após tag, notarização e smoke aprovados."""
import argparse
import json
from pathlib import Path
from prepare_dmg import run, RELEASES, digest
from release_version import bundle_version
from smoke_record import default_record, require_release_obligations, validate

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("folder", type=Path)
parser.add_argument("--repo", required=True)
parser.add_argument("--notes", type=Path, required=True)
parser.add_argument("--smoke-approved", action="store_true", required=True)
parser.add_argument("--smoke-record", type=Path)
args = parser.parse_args()
folder = args.folder.resolve()
if not folder.is_relative_to(RELEASES.resolve()):
    raise SystemExit("Recibo fora de .app-work/releases/.")
manifest = json.loads((folder / "release.json").read_text())
validate(args.smoke_record or default_record(manifest["version"]), manifest["version"])
require_release_obligations()
if manifest["preview"] or manifest["dirty"] or not manifest["notarized"]:
    raise SystemExit("Release exige build limpo, assinatura e notarização confirmadas.")
if Path(manifest["dmg"]).name != manifest["dmg"]:
    raise SystemExit("Nome de artefato inválido.")
if not args.notes.is_file() or not args.notes.read_text().strip():
    raise SystemExit("Notas de release ausentes.")
if run("git", "status", "--porcelain", capture=True):
    raise SystemExit("Árvore precisa permanecer limpa.")
if run("git", "branch", "--show-current", capture=True) != "main":
    raise SystemExit("Publicação parte do commit final em main.")
head = run("git", "rev-parse", "HEAD", capture=True)
bundle_version(manifest["version"])
tag = "v" + manifest["version"]
if head != manifest["sha"] or run("git", "rev-parse", tag + "^{commit}", capture=True) != head:
    raise SystemExit("Tag, main e recibo precisam apontar para o mesmo commit.")
dmg = folder / manifest["dmg"]
expected = f"{digest(dmg)}  {manifest['dmg']}\n{digest(folder / 'release.json')}  release.json\n"
if (folder / "SHA256SUMS").read_text() != expected:
    raise SystemExit("Checksum divergente.")
run("xcrun", "stapler", "validate", dmg)
run("xcrun", "stapler", "validate", folder / manifest["app"])
run("gh", "release", "create", tag, dmg, folder / "SHA256SUMS", folder / "release.json", "--repo", args.repo,
    "--verify-tag", "--draft", *(["--prerelease", "--latest=false"] if "-" in manifest["version"] else []), "--title", "hexa " + manifest["version"], "--notes-file", args.notes.resolve())
print("Rascunho criado. Revisar os assets antes de publicar a release.")
