#!/usr/bin/env python3
"""Cria o rascunho GitHub com DMG e anexa appcast.xml; publicar latest exige flag e os dois assets."""
import argparse
import json
import subprocess
from pathlib import Path

from prepare_dmg import RELEASES, digest, run as default_run
from release_version import bundle_version
from smoke_record import default_record, validate

APPCAST_NAME = "appcast.xml"


def default_run_gh(argv):
    argv = [str(a) for a in argv]
    if not argv or Path(argv[0]).name != "gh":
        raise SystemExit("comando gh inválido")
    completed = subprocess.run(argv, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.stderr.strip() or f"gh saiu {completed.returncode}")
    return completed.stdout


def _stringify(argv):
    return [str(item) for item in argv]


def create_draft(manifest, dmg, extras, *, repo, notes, run_gh=default_run_gh):
    dmg = Path(dmg)
    extra_paths = [Path(item) for item in extras]
    for path in extra_paths:
        if path.name == APPCAST_NAME:
            raise SystemExit("appcast.xml não entra no create; use attach_appcast")
    tag = "v" + manifest["version"]
    argv = [
        "gh",
        "release",
        "create",
        tag,
        dmg,
        *extra_paths,
        "--repo",
        repo,
        "--verify-tag",
        "--draft",
    ]
    if "-" in manifest["version"]:
        argv.extend(["--prerelease", "--latest=false"])
    argv.extend(["--title", "hexa " + manifest["version"], "--notes-file", Path(notes).resolve()])
    run_gh(_stringify(argv))
    return tag


def attach_appcast(tag, appcast_path, *, repo, run_gh=default_run_gh):
    path = Path(appcast_path)
    if path.name != APPCAST_NAME:
        raise SystemExit(f"o feed deve se chamar {APPCAST_NAME}")
    if not path.is_file():
        raise SystemExit("appcast.xml ausente")
    run_gh(
        [
            "gh",
            "release",
            "upload",
            tag,
            str(path.resolve()),
            "--repo",
            repo,
            "--clobber",
        ]
    )
    return path.name


def list_release_assets(tag, *, repo, run_gh=default_run_gh):
    raw = run_gh(["gh", "release", "view", tag, "--repo", repo, "--json", "assets"])
    data = json.loads(raw or "{}")
    return [asset["name"] for asset in data.get("assets", [])]


def assert_complete_assets(asset_names, dmg_name):
    names = {Path(name).name for name in asset_names}
    missing = []
    expected_dmg = Path(dmg_name).name
    if expected_dmg not in names:
        missing.append(expected_dmg)
    if APPCAST_NAME not in names:
        missing.append(APPCAST_NAME)
    if missing:
        raise SystemExit("rascunho incompleto para latest: " + ", ".join(missing))


def publish_release(tag, dmg_name, *, repo, run_gh=default_run_gh, asset_names=None):
    names = list(asset_names) if asset_names is not None else list_release_assets(tag, repo=repo, run_gh=run_gh)
    assert_complete_assets(names, dmg_name)
    run_gh(["gh", "release", "edit", tag, "--repo", repo, "--draft=false"])


def run_draft_sequence(manifest, folder, appcast_path, *, repo, notes, publish=False, run_gh=default_run_gh):
    folder = Path(folder)
    dmg = folder / manifest["dmg"]
    extras = [folder / "SHA256SUMS", folder / "release.json"]
    tag = create_draft(manifest, dmg, extras, repo=repo, notes=notes, run_gh=run_gh)
    attach_appcast(tag, appcast_path, repo=repo, run_gh=run_gh)
    if publish:
        publish_release(tag, manifest["dmg"], repo=repo, run_gh=run_gh)
    return tag


def main(
    argv=None,
    *,
    run_gh=default_run_gh,
    run=default_run,
    validate_smoke=validate,
):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--smoke-approved", action="store_true", required=True)
    parser.add_argument("--smoke-record", type=Path)
    parser.add_argument("--appcast", type=Path)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args(argv)
    folder = args.folder.resolve()
    if not folder.is_relative_to(RELEASES.resolve()):
        raise SystemExit("Recibo fora de .app-work/releases/.")
    manifest = json.loads((folder / "release.json").read_text())
    validate_smoke(args.smoke_record or default_record(manifest["version"]), manifest["version"])
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
    if args.appcast is None:
        raise SystemExit("informe --appcast com o arquivo appcast.xml")
    run_draft_sequence(
        manifest,
        folder,
        args.appcast,
        repo=args.repo,
        notes=args.notes,
        publish=args.publish,
        run_gh=run_gh,
    )
    if args.publish:
        print("Release publicada com DMG e appcast.xml.")
    else:
        print("Rascunho criado com DMG e appcast.xml. Publicar exige --publish e pedido explícito.")


if __name__ == "__main__":
    main()
