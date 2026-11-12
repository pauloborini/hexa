#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Ciclo de vida da chave EdDSA Sparkle: init, backup criptografado, restore e perda."""
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT_PUBLIC_KEY = HERE / "sparkle_ed_public.txt"
PRIVATE_NAME = "ed25519.key"
VOLUME_NAME = "hexa-sparkle-eddsa"
LOSS_MESSAGE = (
    "A chave EdDSA e o backup estão ausentes. "
    "Suspenda o canal de atualização e use o DMG manual. "
    "Não gere uma chave nova como continuidade."
)
SPARKLE_TOOLS = {"generate_keys", "sign_update"}


class SparkleCommandError(Exception):
    def __init__(self, argv, returncode, stdout="", stderr=""):
        self.argv = list(argv)
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
        super().__init__(f"Sparkle {argv[0]} saiu {returncode}")


def sparkle_tool_path(tool):
    bindir = os.environ.get("SPARKLE_BIN", "").strip()
    if bindir:
        return str(Path(bindir) / tool)
    found = shutil.which(tool)
    if not found:
        raise SystemExit(
            f"ferramenta Sparkle '{tool}' ausente; defina SPARKLE_BIN ou o PATH (versão 2.10.1)"
        )
    return found


def default_run_sparkle(argv):
    argv = list(argv)
    if not argv:
        raise SystemExit("comando Sparkle vazio")
    tool = argv[0]
    if tool not in SPARKLE_TOOLS:
        raise SystemExit(f"ferramenta Sparkle recusada: {tool}")
    completed = subprocess.run(
        [sparkle_tool_path(tool), *argv[1:]],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise SparkleCommandError(argv, completed.returncode, completed.stdout, completed.stderr)
    return completed.stdout


def inside_repo(path):
    resolved = Path(path).resolve()
    return resolved == ROOT or resolved.is_relative_to(ROOT)


def _require_outside_repo(path, label):
    if inside_repo(path):
        raise SystemExit(f"{label} recusado dentro do repositório")


def _first_line(text):
    for line in text.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def public_key(public_key_path=DEFAULT_PUBLIC_KEY):
    path = Path(public_key_path)
    if not path.is_file():
        raise SystemExit("registro público EdDSA ausente")
    key = _first_line(path.read_text())
    if not key:
        raise SystemExit("registro público EdDSA vazio")
    return key


def refuse_loss_regenerate():
    raise SystemExit(LOSS_MESSAGE)


def _keychain_public(run_sparkle):
    try:
        return _first_line(run_sparkle(["generate_keys", "-p"]))
    except SparkleCommandError:
        return ""


def init_keys(public_key_path=DEFAULT_PUBLIC_KEY, run_sparkle=default_run_sparkle):
    path = Path(public_key_path)
    recorded = _first_line(path.read_text()) if path.is_file() else ""
    printed = _keychain_public(run_sparkle)
    if recorded and not printed:
        refuse_loss_regenerate()
    if not recorded and not printed:
        run_sparkle(["generate_keys"])
        printed = _keychain_public(run_sparkle)
        if not printed:
            raise SystemExit("generate_keys não imprimiu a chave pública")
    if recorded and printed and recorded != printed:
        raise SystemExit("chave pública do Chaveiro diverge do registro")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(printed + "\n")
    return printed


def _temp_outside_repo(kind):
    if kind == "file":
        handle, name = tempfile.mkstemp(prefix="hexa-sparkle-x-")
        os.close(handle)
        path = Path(name)
    else:
        path = Path(tempfile.mkdtemp(prefix="hexa-sparkle-src-"))
    try:
        _require_outside_repo(path, "temporário Sparkle")
    except SystemExit:
        if kind == "file":
            path.unlink(missing_ok=True)
        else:
            shutil.rmtree(path, ignore_errors=True)
        raise
    return path


def _create_encrypted_image(src_folder, dest_image, password):
    completed = subprocess.run(
        [
            "/usr/bin/hdiutil",
            "create",
            "-ov",
            "-encryption",
            "AES-256",
            "-stdinpass",
            "-srcfolder",
            str(src_folder),
            "-format",
            "UDZO",
            "-volname",
            VOLUME_NAME,
            str(dest_image),
        ],
        input=password + "\n",
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise SystemExit("falha ao criar imagem criptografada do backup EdDSA")


def _mount_point(stdout):
    for token in stdout.split():
        if token.startswith("/Volumes/"):
            return Path(token)
    raise SystemExit("não foi possível montar a imagem de backup")


def _attach_image(image, password):
    completed = subprocess.run(
        [
            "/usr/bin/hdiutil",
            "attach",
            "-stdinpass",
            "-readonly",
            "-nobrowse",
            str(image),
        ],
        input=password + "\n",
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise SystemExit("falha ao abrir a imagem criptografada do backup EdDSA")
    return _mount_point(completed.stdout)


def _detach_image(mount):
    if mount is None:
        return
    subprocess.run(
        ["/usr/bin/hdiutil", "detach", str(mount), "-quiet"],
        capture_output=True,
        text=True,
        check=False,
    )


def _private_on_volume(mount):
    named = mount / PRIVATE_NAME
    if named.is_file():
        return named
    files = [path for path in mount.iterdir() if path.is_file() and path.name != ".DS_Store"]
    if len(files) != 1:
        raise SystemExit("imagem de backup sem a chave exportada")
    return files[0]


def export_backup(dest_image, password, run_sparkle=default_run_sparkle):
    dest = Path(dest_image)
    _require_outside_repo(dest, "imagem de backup EdDSA")
    if not password:
        raise SystemExit("senha do backup ausente")
    x_path = None
    src_dir = None
    try:
        x_path = _temp_outside_repo("file")
        run_sparkle(["generate_keys", "-x", str(x_path)])
        if not x_path.is_file() or x_path.stat().st_size == 0:
            raise SystemExit("generate_keys -x não gravou o export")
        src_dir = _temp_outside_repo("dir")
        shutil.copy2(x_path, src_dir / PRIVATE_NAME)
        x_path.unlink()
        x_path = None
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            _create_encrypted_image(src_dir, dest, password)
        except OSError:
            raise SystemExit("falha ao criar imagem criptografada do backup EdDSA")
    finally:
        if x_path is not None:
            Path(x_path).unlink(missing_ok=True)
        if src_dir is not None:
            shutil.rmtree(src_dir, ignore_errors=True)
    if not dest.is_file():
        raise SystemExit("imagem de backup EdDSA não foi criada")
    print("backup gravado:", dest)
    return dest


def restore_backup(
    image,
    password,
    public_key_path=DEFAULT_PUBLIC_KEY,
    run_sparkle=default_run_sparkle,
    fixture_bytes=b"hexa-sparkle-restore-fixture",
):
    image = Path(image)
    if not image.is_file():
        raise SystemExit("imagem de backup EdDSA ausente")
    if not password:
        raise SystemExit("senha do backup ausente")
    recorded = public_key(public_key_path)
    mount = None
    fixture_path = None
    try:
        mount = _attach_image(image, password)
        private_file = _private_on_volume(mount)
        run_sparkle(["generate_keys", "-f", str(private_file)])
        printed = _keychain_public(run_sparkle)
        if printed != recorded:
            raise SystemExit("chave pública restaurada diverge do registro")
        handle, name = tempfile.mkstemp(prefix="hexa-sparkle-sign-")
        os.close(handle)
        fixture_path = Path(name)
        _require_outside_repo(fixture_path, "temporário Sparkle")
        fixture_path.write_bytes(fixture_bytes)
        output = run_sparkle(["sign_update", str(fixture_path)])
        if "sparkle:edSignature" not in output:
            raise SystemExit("sign_update não emitiu sparkle:edSignature")
        return output
    finally:
        if fixture_path is not None:
            Path(fixture_path).unlink(missing_ok=True)
        _detach_image(mount)


def _read_password(password_file):
    if password_file is None:
        import getpass

        return getpass.getpass("senha do backup EdDSA: ")
    path = Path(password_file)
    _require_outside_repo(path, "arquivo de senha")
    if not path.is_file():
        raise SystemExit("arquivo de senha ausente")
    lines = path.read_text().splitlines()
    return lines[0] if lines else ""


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["init", "export", "restore"])
    parser.add_argument("--image", type=Path)
    parser.add_argument("--password-file", type=Path)
    parser.add_argument("--public-key", type=Path, default=DEFAULT_PUBLIC_KEY)
    args = parser.parse_args(argv)
    if args.command == "init":
        init_keys(public_key_path=args.public_key)
        return
    if args.image is None:
        raise SystemExit("--image é obrigatório para export e restore")
    password = _read_password(args.password_file)
    if args.command == "export":
        export_backup(args.image, password)
        return
    restore_backup(args.image, password, public_key_path=args.public_key)


if __name__ == "__main__":
    main()
