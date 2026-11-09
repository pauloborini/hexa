#!/usr/bin/env python3
"""Envio explícito à Apple: notariza e stapla app e DMG. Não publica no GitHub."""
import argparse
import json
from pathlib import Path
import sys
from prepare_dmg import run, create_dmg, checksums, RELEASES, signature, signing_identity

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("folder", type=Path)
parser.add_argument("--keychain-profile", required=True)
parser.add_argument("--identity")
args = parser.parse_args()
folder = args.folder.resolve()
if not folder.is_relative_to(RELEASES.resolve()):
    raise SystemExit("O recibo deve ficar em .app-work/releases/.")
manifest = json.loads((folder / "release.json").read_text())
if manifest["app"] != "hexa.app" or Path(manifest["dmg"]).name != manifest["dmg"] or not manifest["dmg"].endswith("-arm64.dmg"):
    raise SystemExit("Recibo incompatível com o procedimento.")
if manifest["preview"] or manifest["dirty"]:
    raise SystemExit("Prévia ou build dirty não pode ser enviado como release.")
app = folder / manifest["app"]
dmg = folder / manifest["dmg"]
if "Authority=Developer ID Application:" not in signature(app):
    raise SystemExit("O app exige assinatura Developer ID Application antes do envio.")

def submit(path, receipt):
    result = run("xcrun", "notarytool", "submit", path, "--keychain-profile", args.keychain_profile,
                 "--wait", "--output-format", "json", capture=True)
    receipt.write_text(result + "\n")
    if json.loads(result).get("status") != "Accepted":
        raise SystemExit("Apple não aceitou o artefato; consultar recibo local.")

archive = folder / "app-notary.zip"
run("ditto", "-c", "-k", "--keepParent", app, archive)
submit(archive, folder / "notary-app.json")
run("xcrun", "stapler", "staple", app)
run("xcrun", "stapler", "validate", app)
run("codesign", "--verify", "--deep", "--strict", app)
# Reempacotar somente este artefato produzido pelo procedimento.
dmg.unlink()
create_dmg(app, dmg, "hexa")
identity = signing_identity(False, args.identity)
run("codesign", "--force", "--sign", identity, "--timestamp", "--identifier", "io.github.pauloborini.hexa.diskimage", dmg)
run("codesign", "--verify", "--strict", dmg)
submit(dmg, folder / "notary-dmg.json")
run("xcrun", "stapler", "staple", dmg)
run("xcrun", "stapler", "validate", dmg)
run("spctl", "--assess", "--type", "execute", app)
manifest["notarized"] = True
(folder / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
checksums(folder, manifest["dmg"])
print("App e DMG notarizados; checksum final atualizado.")
