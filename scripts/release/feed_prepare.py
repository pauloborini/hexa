#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepara appcast.xml local assinado com enclosure versionada; fail-closed no canal."""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import sparkle_keys
import write_cask

APPCAST_NAME = "appcast.xml"
FEED_TOOLS = {"generate_appcast", "sign_update"}
LATEST_DMG_MARKER = "/releases/latest/download/"
SparkleCommandError = sparkle_keys.SparkleCommandError


class PrepareResult:
    def __init__(self, channel_ready, appcast_path=None, error=None):
        self.channel_ready = channel_ready
        self.appcast_path = None if appcast_path is None else Path(appcast_path)
        self.error = error


def enclosure_url(version):
    return write_cask.DOWNLOAD_URL.replace("#{version}", str(version))


def dmg_name(version):
    return f"hexa-{version}-arm64.dmg"


def download_url_prefix(version):
    url = enclosure_url(version)
    suffix = dmg_name(version)
    if not url.endswith(suffix):
        raise SystemExit("padrão D6 inesperado para o prefixo do enclosure")
    return url[: -len(suffix)]


def default_run_sparkle(argv):
    argv = list(argv)
    if not argv:
        raise SystemExit("comando Sparkle vazio")
    tool = argv[0]
    if tool not in FEED_TOOLS:
        raise SystemExit(f"ferramenta Sparkle recusada: {tool}")
    if "-s" in argv[1:]:
        raise SystemExit("Sparkle -s é recusado para chave nova")
    completed = subprocess.run(
        [sparkle_keys.sparkle_tool_path(tool), *argv[1:]],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise SparkleCommandError(argv, completed.returncode, completed.stdout, completed.stderr)
    return completed.stdout


def _enclosure_url(xml):
    match = re.search(r'<enclosure\b[^>]*\burl="([^"]+)"', xml)
    return match.group(1) if match else ""


def _has_ed_signature(xml):
    return bool(re.search(r'\bsparkle:edSignature="[^"]+"', xml))


def _contains_private_export(xml):
    return "BEGIN PRIVATE KEY" in xml or "BEGIN OPENSSH PRIVATE KEY" in xml


def _inject_signature(xml, sign_output):
    match = re.search(r'sparkle:edSignature="([^"]+)"', sign_output)
    if not match:
        raise SparkleCommandError(["sign_update"], 1, sign_output, "sign_update sem sparkle:edSignature")
    signature = match.group(1)

    def repl(found):
        return f'{found.group(1)} sparkle:edSignature="{signature}"{found.group(2)}'

    updated, count = re.subn(r"(<enclosure\b[^>]*?)(\s*/>|>)", repl, xml, count=1)
    if count != 1:
        raise SparkleCommandError(["sign_update"], 1, sign_output, "enclosure ausente no appcast")
    return updated


def require_signature(xml, dmg, *, inject=True, run_sparkle=default_run_sparkle):
    if _has_ed_signature(xml) or not inject:
        return xml
    output = run_sparkle(["sign_update", str(dmg)])
    if "sparkle:edSignature" not in output:
        raise SparkleCommandError(["sign_update", str(dmg)], 1, output, "sign_update sem sparkle:edSignature")
    return _inject_signature(xml, output)


def channel_ready(appcast_path, version):
    if not appcast_path:
        return False
    path = Path(appcast_path)
    if path.name != APPCAST_NAME or not path.is_file():
        return False
    xml = path.read_text()
    url = _enclosure_url(xml)
    if not url or url != enclosure_url(version):
        return False
    if LATEST_DMG_MARKER in url and url.endswith(".dmg"):
        return False
    if not _has_ed_signature(xml):
        return False
    if _contains_private_export(xml):
        return False
    return True


def _stage_dmg(dmg, version, workdir):
    expected = dmg_name(version)
    if dmg.name != expected:
        raise SparkleCommandError(["prepare_appcast"], 1, "", f"nome do DMG deve ser {expected}")
    workdir.mkdir(parents=True, exist_ok=True)
    staged = workdir / expected
    if dmg.resolve() != staged.resolve():
        shutil.copy2(dmg, staged)
    return staged


def prepare_appcast(
    dmg,
    version,
    workdir,
    run_sparkle=default_run_sparkle,
    *,
    inject_signature=True,
):
    dmg = Path(dmg)
    workdir = Path(workdir)
    appcast_path = workdir / APPCAST_NAME
    try:
        staged = _stage_dmg(dmg, version, workdir)
        argv = [
            "generate_appcast",
            "--download-url-prefix",
            download_url_prefix(version),
            "-o",
            str(appcast_path),
            "--maximum-deltas",
            "0",
            str(workdir),
        ]
        run_sparkle(argv)
        if not appcast_path.is_file():
            return PrepareResult(False, appcast_path, "generate_appcast não gravou appcast.xml")
        xml = require_signature(
            appcast_path.read_text(),
            staged,
            inject=inject_signature,
            run_sparkle=run_sparkle,
        )
        appcast_path.write_text(xml)
        ready = channel_ready(appcast_path, version)
        error = None if ready else "appcast recusado para o canal"
        return PrepareResult(ready, appcast_path, error)
    except SparkleCommandError as exc:
        return PrepareResult(False, appcast_path if appcast_path.is_file() else None, str(exc))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dmg", type=Path)
    parser.add_argument("version")
    parser.add_argument("--workdir", type=Path)
    args = parser.parse_args(argv)
    workdir = args.workdir or Path(tempfile.mkdtemp(prefix="hexa-feed-"))
    result = prepare_appcast(args.dmg, args.version, workdir)
    if not result.channel_ready:
        raise SystemExit(result.error or "canal não ready")
    print("appcast:", result.appcast_path)


if __name__ == "__main__":
    main()
