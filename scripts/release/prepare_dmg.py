#!/usr/bin/env python3
"""Prepara bundle arm64 e DMG local. Não cria tags nem publica arquivos."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
from source_snapshot import snapshot
from release_version import current_version, bundle_version
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
RELEASES = ROOT / ".app-work/releases"
ARTWORK = RELEASES / "artwork"
ENTITLEMENTS = ROOT / "Resources/Hexa.entitlements"

def run(*args, capture=False):
    result = subprocess.run([str(a) for a in args], check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None

def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def signature(path):
    result = subprocess.run(["codesign", "-dv", "--verbose=4", str(path)], capture_output=True, text=True, check=True)
    return result.stderr

def signing_identity(preview, requested):
    data = run("security", "find-identity", "-v", "-p", "codesigning", capture=True)
    records = re.findall(r'^\s*\d+\) ([a-fA-F0-9]{40}) "([^"]+)"', data, re.MULTILINE)
    developer_id = [r for r in records if r[1].startswith("Developer ID Application:")]
    # A prévia aceita identidade de desenvolvimento, mas prefere Developer ID:
    # no macOS 27 a ocultação da menu bar só ativa nessa assinatura.
    candidates = records if preview and (requested or not developer_id) else developer_id
    if requested:
        chosen = [r for r in candidates if requested in r]
    else:
        chosen = candidates
    if len(chosen) != 1:
        raise SystemExit("Selecione uma identidade válida. Distribuição exige Developer ID Application; a prévia aceita identidade de desenvolvimento.")
    return chosen[0][0]

def require_dmg_prerequisites():
    missing = [name for name in ("ds_store", "mac_alias") if importlib.util.find_spec(name) is None]
    if missing:
        raise SystemExit("Módulos Python ausentes (" + ", ".join(missing) + "); instale scripts/release/requirements.txt")
    if not (ARTWORK / "background.png").is_file():
        raise SystemExit("Gere a arte com scripts/release/generate-artwork.sh")

def create_dmg(app, output, volume_name):
    from ds_store import DSStore
    from mac_alias import Alias
    if not (ARTWORK / "background.png").is_file():
        raise SystemExit("Gere a arte com scripts/release/generate-artwork.sh")
    with tempfile.TemporaryDirectory(prefix="dmg-", dir=output.parent) as work:
        work = Path(work)
        rw = work / "installer-rw.dmg"
        size = max(256, sum(p.stat().st_size for p in app.rglob("*") if p.is_file()) // (1024 * 1024) * 2 + 64)
        run("hdiutil", "create", "-size", f"{size}m", "-fs", "HFS+", "-volname", volume_name, rw)
        mounted = plistlib.loads(run("hdiutil", "attach", rw, "-plist", "-nobrowse", "-noautoopen", capture=True).encode())
        mount = Path(next(item["mount-point"] for item in mounted["system-entities"] if "mount-point" in item))
        try:
            run("ditto", app, mount / "hexa.app")
            shutil.copy2(ROOT / "LICENSE", mount / "LICENSE")
            (mount / "Applications").symlink_to("/Applications")
            background = mount / ".background"
            background.mkdir()
            shutil.copy2(ARTWORK / "background.png", background / "background.png")
            alias = Alias.for_file(str(background / "background.png")).to_bytes()
            if b"/Users/" in alias:
                raise SystemExit("Alias de fundo contém caminho privado; não distribuir.")
            with DSStore.open(str(mount / ".DS_Store"), "w+") as store:
                store["."]["bwsp"] = {"WindowBounds": "{{100, 100}, {720, 528}}", "ShowToolbar": False,
                                       "ShowStatusBar": False, "ShowPathbar": False, "ShowSidebar": False,
                                       "ShowTabView": False, "ContainerShowSidebar": False}
                store["."]["icvp"] = {"viewOptionsVersion": 1, "backgroundType": 2, "backgroundImageAlias": alias,
                                       "backgroundColorRed": 246/255, "backgroundColorGreen": 244/255, "backgroundColorBlue": 238/255,
                                       "iconSize": 96.0, "textSize": 12.0, "labelOnBottom": True,
                                       "showItemInfo": False, "showIconPreview": True,
                                       "gridSpacing": 100.0, "gridOffsetX": 0.0, "gridOffsetY": 0.0, "arrangeBy": "none"}
                store["."]["vstl"] = ("type", "icnv")
                store["hexa.app"]["Iloc"] = (175, 358)
                store["Applications"]["Iloc"] = (545, 358)
                store["LICENSE"]["Iloc"] = (656, 68)
        finally:
            run("hdiutil", "detach", mount)
        run("hdiutil", "convert", rw, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", output)
        run("hdiutil", "verify", output)

def checksums(folder, filename):
    path = folder / filename
    rows = [f"{digest(path)}  {filename}\n"]
    if (folder / "release.json").is_file():
        rows.append(f"{digest(folder / 'release.json')}  release.json\n")
    (folder / "SHA256SUMS").write_text("".join(rows))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True, help="Bundle base do build local")
    parser.add_argument("--products", type=Path, default=RELEASES / "release-products")
    parser.add_argument("--version", default=current_version(), help="Versão pública; padrão: ReleaseVersion.txt")
    parser.add_argument("--build", type=int, help="Número incremental de build (1 a 9999)")
    parser.add_argument("--identity", default=os.environ.get("HEXA_RELEASE_IDENTITY"))
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--output", type=Path)
    options = parser.parse_args()
    os.chdir(ROOT)
    if not options.app.is_dir():
        parser.error("Bundle base ausente; gere-o com ./build.sh --release")
    if not ENTITLEMENTS.is_file():
        parser.error("Arquivo de entitlements ausente: " + str(ENTITLEMENTS))
    # Antes de criar a pasta da versão: uma falha aqui não deixa resto para trás.
    require_dmg_prerequisites()
    try:
        numeric_version = bundle_version(options.version)
    except ValueError as error:
        parser.error(str(error))
    if not options.preview and (not options.build or not 1 <= options.build <= 9999):
        parser.error("Distribuição exige --build 1..9999")
    dirty = bool(run("git", "status", "--porcelain", capture=True))
    sha = run("git", "rev-parse", "HEAD", capture=True)
    if not options.preview and dirty:
        parser.error("A release exige árvore limpa e commit final validado; WIP paralelo não é incorporado em uma release.")
    if not options.preview and run("git", "branch", "--show-current", capture=True) != "main":
        parser.error("O contrato atual empacota o commit final em main.")
    # Verificar todas as arquiteturas antes de copiar ou assinar.
    names = ["Hexa", "FanControlHelper", "libNowPlayingAdapter.dylib"]
    for name in names:
        architectures = set(run("lipo", "-archs", options.products / name, capture=True).split())
        if architectures != {"arm64"}:
            parser.error("Produto não é arm64: " + name)
    provenance = json.loads((options.products / "build.json").read_text())
    current_source = snapshot()
    if provenance["sha"] != sha or provenance["sourceHash"] != current_source["sourceHash"]:
        parser.error("Produtos não correspondem às fontes/commit atuais; recompilar com build-release.sh.")
    for name in names:
        if digest(options.products / name) != provenance["binaries"][name]:
            parser.error("Produto alterado após o build de release.")
    if not options.preview and provenance["dirty"]:
        parser.error("Produtos compilados com WIP; recompilar a partir da árvore limpa.")
    identity = signing_identity(options.preview, options.identity)
    identifier = "preview-" + datetime.now().strftime("%Y%m%d-%H%M%S") if options.preview else options.version
    folder = (options.output or RELEASES / identifier).resolve()
    if not folder.is_relative_to(RELEASES.resolve()):
        parser.error("Artefatos e recibos devem ficar em .app-work/releases/")
    folder.mkdir(parents=True, exist_ok=False)
    app = folder / "hexa.app"
    run("ditto", options.app.resolve(), app)
    for name in names:
        destination = app / "Contents" / ("Frameworks" if name.endswith(".dylib") else "MacOS") / name
        shutil.copy2(options.products / name, destination)
    run("ditto", options.products / "hexa_Hexa.bundle", app / "Contents/Resources/hexa_Hexa.bundle")
    shutil.copy2(ROOT / "Sources/Hexa/Resources/Brand/AppIcon.icns", app / "Contents/Resources/AppIcon.icns")
    bundle_icon = app / "Contents/Resources/hexa_Hexa.bundle/Brand/AppIcon.icns"
    if bundle_icon.parent.exists():
        shutil.copy2(ROOT / "Sources/Hexa/Resources/Brand/AppIcon.icns", bundle_icon)
    executable = app / "Contents/MacOS/Hexa"
    rpaths = run("otool", "-l", executable, capture=True)
    if "@executable_path/../Frameworks" not in rpaths:
        run("install_name_tool", "-add_rpath", "@executable_path/../Frameworks", executable)
    for stale in sorted(set(re.findall(r"path (.+/PackageFrameworks) \(offset", rpaths))):
        run("install_name_tool", "-delete_rpath", stale, executable)
    info_path = app / "Contents/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    if info.get("CFBundleIdentifier") != "io.github.pauloborini.hexa":
        parser.error("Bundle base deve ser io.github.pauloborini.hexa; probes não são instaladores de release.")
    info["HexaFanControlHelperVersion"] = digest(app / "Contents/MacOS/FanControlHelper")
    info["HexaBuildCommit"] = f"{sha[:7]}{'-dirty' if dirty else ''} · {datetime.now():%Y-%m-%d %H:%M}"
    info["HexaReleasePreview"] = options.preview
    info["HexaReleaseVersion"] = options.version
    info["CFBundleShortVersionString"] = numeric_version
    if not options.preview:
        info["CFBundleVersion"] = str(options.build)
    info_path.write_bytes(plistlib.dumps(info))
    signing_options = ["--timestamp=none"] if options.preview else ["--options", "runtime", "--timestamp"]
    for name in ["libNowPlayingAdapter.dylib", "FanControlHelper", "Hexa"]:
        path = app / "Contents" / ("Frameworks" if name.endswith(".dylib") else "MacOS") / name
        extra = ["--identifier", "io.github.pauloborini.hexa.fan-control"] if name == "FanControlHelper" else []
        if name == "Hexa":
            extra += ["--entitlements", "Resources/Hexa.entitlements"]
        run("codesign", "--force", "--sign", identity, *signing_options, *extra, path)
    run("codesign", "--force", "--sign", identity, *signing_options, "--entitlements", "Resources/Hexa.entitlements", app)
    run("codesign", "--verify", "--deep", "--strict", app)
    app_signature = signature(app)
    helper_signature = signature(app / "Contents/MacOS/FanControlHelper")
    team = re.search(r"TeamIdentifier=(\S+)", app_signature)
    helper_team = re.search(r"TeamIdentifier=(\S+)", helper_signature)
    if not team or not helper_team or team[1] == "not" or team[1] != helper_team[1]:
        raise SystemExit("App e helper precisam do mesmo Team ID autenticado.")
    if not options.preview and ("Authority=Developer ID Application:" not in app_signature or "runtime" not in app_signature):
        raise SystemExit("Assinatura de distribuição inválida.")
    filename = "hexa-PREVIEW-arm64.dmg" if options.preview else f"hexa-{options.version}-arm64.dmg"
    create_dmg(app, folder / filename, "hexa PREVIEW" if options.preview else "hexa")
    run("codesign", "--force", "--sign", identity, "--timestamp=none" if options.preview else "--timestamp",
        "--identifier", "io.github.pauloborini.hexa.diskimage", folder / filename)
    run("codesign", "--verify", "--strict", folder / filename)
    manifest = {"version": info["HexaReleaseVersion"], "bundleVersion": info["CFBundleShortVersionString"],
                "prerelease": "-" in options.version, "build": info["CFBundleVersion"],
                "sha": sha, "architectures": ["arm64"], "preview": options.preview,
                "dirty": dirty, "notarized": False, "dmg": filename, "app": "hexa.app",
                "createdUTC": datetime.now(timezone.utc).isoformat()}
    (folder / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    checksums(folder, filename)
    print("DMG local gerado:", folder / filename)
    print("Notarização/publicação: não executadas.")

if __name__ == "__main__":
    main()
