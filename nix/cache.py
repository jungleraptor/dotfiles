#!/usr/bin/env python3
"""Build/export a Brix Home Manager generation, or import it without activation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from urllib.parse import quote, urlencode


REPO = Path(__file__).resolve().parent.parent
PROFILE = "brix-root"
SYSTEM = "x86_64-linux"
STORE_PATH = re.compile(r"/nix/store/[0-9a-z]{32}-[^/\s]+\Z")


def run(command, *, capture=False, stdin=None):
    print("+ " + " ".join(map(str, command)), file=sys.stderr, flush=True)
    result = subprocess.run(
        list(map(str, command)), check=True, text=True, input=stdin,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else None


def nix(*args, capture=False, stdin=None):
    return run(
        [NIX, "--extra-experimental-features", "nix-command flakes", *args],
        capture=capture, stdin=stdin,
    )


def keep_paths(bundle, paths):
    """Register GC roots on this machine, including after transferring the bundle."""
    roots = bundle / "roots"
    roots.mkdir(exist_ok=True)
    for path in paths:
        run([
            Path(NIX).parent / "nix-store", "--option", "substituters", "",
            "--add-root", roots / Path(path).name, "--realise", path,
        ])


def archive_paths(archive):
    # Relative inputs can already live inside their parent's archived source.
    paths = {archive["path"]} if "path" in archive else set()
    for child in archive.get("inputs", {}).values():
        paths.update(archive_paths(child))
    return sorted(paths)


def export_bundle(bundle, key_file):
    if bundle == REPO or REPO in bundle.parents:
        raise ValueError("Put the cache bundle outside the dotfiles checkout.")
    if key_file in (REPO, bundle) or REPO in key_file.parents or bundle in key_file.parents:
        raise ValueError("Keep the signing key outside both the checkout and bundle.")
    if (bundle / "manifest.json").exists():
        raise ValueError("This bundle is complete. Choose a new directory for a new generation.")
    bundle.mkdir(parents=True, exist_ok=True)

    # Freeze the working tree, including the migration's still-untracked files.
    # All subsequent evaluations use this immutable source and the existing lock.
    archive = json.loads(nix(
        "flake", "archive", "--json", "--no-update-lock-file",
        f"path:{REPO}", capture=True,
    ))
    sources = archive_paths(archive)
    source = archive["path"]
    keep_paths(bundle, sources)
    generation = nix(
        "build", "--no-update-lock-file", "--print-out-paths",
        "--out-link", str(bundle / "roots" / "generation"),
        f"path:{source}#homeConfigurations.{PROFILE}.activationPackage", capture=True,
    )
    if not STORE_PATH.fullmatch(generation):
        raise ValueError("Expected exactly one generation store path from nix build.")
    checks = [f"checks.{SYSTEM}.{name}" for name in ("neovim", "fish")]
    nix("build", "--no-update-lock-file", "--no-link", *[
        f"path:{source}#{check}" for check in checks
    ])

    key_file.parent.mkdir(parents=True, exist_ok=True)
    if not key_file.exists():
        secret = nix("key", "generate-secret", "--key-name", "dotfiles-cache-1", capture=True)
        # Exclusive creation avoids silently replacing a key from another export.
        fd = os.open(key_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as stream:
            stream.write(secret + "\n")
    if key_file.stat().st_mode & 0o077:
        raise ValueError(f"Signing key must be private: chmod 600 {key_file}")
    public_key = nix("key", "convert-secret-to-public", stdin=key_file.read_text(), capture=True)
    cache_uri = (bundle / "cache").as_uri() + "?" + urlencode(
        {"secret-key": str(key_file)}, quote_via=quote,
    )
    # Sign in the file cache so a normal builder user need not sign daemon-owned paths.
    nix("copy", "--to", cache_uri, generation, *sources)
    (bundle / "cache-public-key").write_text(public_key + "\n")
    manifest = {
        "version": 1,
        "profile": PROFILE,
        "system": SYSTEM,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "nix_version": nix("--version", capture=True),
        "source": source,
        "flake_sources": sources,
        "lock_sha256": hashlib.sha256((Path(source) / "flake.lock").read_bytes()).hexdigest(),
        "generation": generation,
        "public_key": public_key,
        "passed_checks": checks,
    }
    nix("path-info", "--closure-size", "--human-readable", generation)
    # A manifest is the completion marker; failed exports can be retried in place.
    pending = bundle / "manifest.json.tmp"
    pending.write_text(json.dumps(manifest, indent=2) + "\n")
    pending.replace(bundle / "manifest.json")
    print(f"\nBundle ready: {bundle}\nGeneration: {generation}")
    print(f"Keep the private signing key on the builder: {key_file}")
    print("Home Manager has not been activated.")


def import_bundle(bundle):
    if os.geteuid() != 0:
        raise ValueError("Import this brix-root bundle as root on the Research/Brix box.")
    manifest = json.loads((bundle / "manifest.json").read_text())
    if (manifest.get("version"), manifest.get("profile"), manifest.get("system")) != (1, PROFILE, SYSTEM):
        raise ValueError("Expected a version 1 brix-root/x86_64-linux bundle.")
    generation = manifest["generation"]
    source = manifest["source"]
    sources = manifest["flake_sources"]
    if not isinstance(sources, list) or source not in sources:
        raise ValueError("Manifest must include the root flake in flake_sources.")
    paths = [generation, *sources]
    if not all(isinstance(path, str) and STORE_PATH.fullmatch(path) for path in paths):
        raise ValueError("Manifest contains an invalid /nix/store path.")
    public_key = (bundle / "cache-public-key").read_text().strip()
    if public_key != manifest["public_key"] or not re.fullmatch(r"[^\s:]+:[A-Za-z0-9+/=]+", public_key):
        raise ValueError("Bundle public key does not match its manifest.")
    if not (bundle / "cache" / "nix-cache-info").is_file():
        raise ValueError("Missing file cache; transfer the complete bundle first.")

    # Explicit source + no substituters keeps this import independent of public caches.
    # Trust is scoped to this command, not written into system-wide nix.conf.
    nix(
        "copy", "--option", "substituters", "",
        "--option", "require-sigs", "true",
        "--extra-trusted-public-keys", public_key,
        "--from", (bundle / "cache").as_uri(), *paths,
    )
    keep_paths(bundle, paths)
    if hashlib.sha256((Path(source) / "flake.lock").read_bytes()).hexdigest() != manifest["lock_sha256"]:
        raise ValueError("Imported flake.lock does not match the manifest.")
    evaluated = nix(
        "eval", "--offline", "--no-update-lock-file", "--raw",
        f"path:{source}#homeConfigurations.{PROFILE}.activationPackage.outPath", capture=True,
    )
    if evaluated != generation:
        raise ValueError("Offline evaluation produced a different generation from the manifest.")
    print(f"\nImported and checked offline: {generation}")
    print(f"Inspect managed files in: {generation}/home-files")
    print("Home Manager has not been activated. Follow INSTALL.md before switching.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export", help="Build, check, and sign a bundle on the Linux builder")
    export.add_argument("bundle", type=Path, help="New bundle directory outside the checkout")
    export.add_argument(
        "--key-file", type=Path,
        default=Path.home() / ".local/state/dotfiles-cache/signing-key",
    )
    restore = commands.add_parser("import", help="Import on a root Brix box; never activate")
    restore.add_argument("bundle", type=Path)
    args = parser.parse_args()
    if (platform.system(), platform.machine()) != ("Linux", "x86_64"):
        parser.error("This workflow targets x86_64 Linux builders and Brix boxes.")
    global NIX
    NIX = shutil.which("nix")
    if not NIX:
        installed = Path("/nix/var/nix/profiles/default/bin/nix")
        if not installed.is_file():
            parser.error("Install Nix first; see INSTALL.md.")
        NIX = str(installed)
    try:
        if args.command == "export":
            export_bundle(args.bundle.expanduser().resolve(), args.key_file.expanduser().resolve())
        else:
            import_bundle(args.bundle.expanduser().resolve())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Cache workflow failed: {error}\n")


if __name__ == "__main__":
    main()
