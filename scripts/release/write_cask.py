#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Escreve Casks/hexa.rb a partir do recibo local. Não cria tag nem publica."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RELEASES = ROOT / ".app-work/releases"
DEFAULT_OUTPUT = ROOT / "Casks" / "hexa.rb"
DOWNLOAD_URL = "https://github.com/pauloborini/hexa/releases/download/v#{version}/hexa-#{version}-arm64.dmg"
TAP_COMMAND = "brew tap pauloborini/hexa https://github.com/pauloborini/hexa"


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load_receipt(folder):
    folder = Path(folder).resolve()
    manifest = json.loads((folder / "release.json").read_text())
    if manifest.get("preview") or manifest.get("dirty") or not manifest.get("notarized"):
        raise SystemExit("O cask exige recibo de distribuição limpo e notarizado.")
    version = manifest.get("version")
    dmg_name = manifest.get("dmg")
    expected = f"hexa-{version}-arm64.dmg"
    if dmg_name != expected:
        raise SystemExit("Nome do DMG não corresponde à versão pública.")
    dmg = folder / dmg_name
    if not dmg.is_file():
        raise SystemExit("DMG ausente no recibo.")
    sha = digest(dmg)
    sums = (folder / "SHA256SUMS").read_text()
    if not sums.startswith(f"{sha}  {dmg_name}\n"):
        raise SystemExit("SHA-256 do DMG diverge de SHA256SUMS.")
    return version, sha


def render(version, sha):
    return f"""# SPDX-License-Identifier: GPL-3.0-or-later
cask "hexa" do
  version "{version}"
  sha256 "{sha}"

  url "{DOWNLOAD_URL}"
  name "hexa"
  desc "Menu bar utility for macOS"
  homepage "https://github.com/pauloborini/hexa"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "hexa.app"

  auto_updates false

  caveats <<~EOS
    If /Applications already contains hexa and brew does not replace it, quit the app and overwrite it by hand.
    This tap lives in the hexa repository: {TAP_COMMAND}
  EOS
end
"""


def write_cask(folder, output=DEFAULT_OUTPUT):
    version, sha = load_receipt(folder)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    text = render(version, sha)
    output.write_text(text)
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path, help="Pasta do recibo em .app-work/releases/")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    folder = args.folder.resolve()
    if not folder.is_relative_to(RELEASES.resolve()):
        raise SystemExit("Recibo fora de .app-work/releases/.")
    write_cask(folder, args.output)
    print("Cask escrito:", args.output)


if __name__ == "__main__":
    main()
