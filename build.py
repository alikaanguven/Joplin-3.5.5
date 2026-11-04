#!/usr/bin/env python3
"""Build the isolated ARM64 Joplin 3.5.5 application without installing it."""

import argparse
import hashlib
import os
from pathlib import Path
import platform
import plistlib
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
VERSION = "3.5.5"
BUNDLE_ID = "local.joplin.institute355"
ASAR_HEADER_SHA256 = "cd9e0c03b8650de222abc2ea5617a79aa43f3942918ffef7b3836f8a0048b8de"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def validate_source(source):
    info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleShortVersionString") != VERSION:
        raise ValueError("Use the official Joplin 3.5.5 ARM64 macOS application.")
    if info.get("CFBundleExecutable") != "Joplin":
        raise ValueError("The source application has an unexpected executable.")
    if (source / "Contents/MacOS/JoplinCore").exists():
        raise ValueError("Use an unmodified vendor app, not a previous custom build.")
    executable = source / "Contents/MacOS/Joplin"
    architectures = subprocess.check_output(
        ["/usr/bin/lipo", "-archs", str(executable)], text=True
    ).split()
    if "arm64" not in architectures:
        raise ValueError("The source application does not contain an ARM64 executable.")
    with (source / "Contents/Resources/app.asar").open("rb") as stream:
        prefix = stream.read(16)
        if len(prefix) != 16:
            raise ValueError("The Joplin application archive is incomplete.")
        header_size = struct.unpack("<4I", prefix)[3]
        if header_size > 32 * 1024 * 1024:
            raise ValueError("The Joplin application archive header is invalid.")
        header = stream.read(header_size)
    if hashlib.sha256(header).hexdigest() != ASAR_HEADER_SHA256:
        raise ValueError("The application archive does not match the tested release.")
    # Verify the original signature before any packaging changes.
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", source)
    return info


def build(source, output, icon):
    if sys.platform != "darwin" or platform.machine() != "arm64":
        raise ValueError("Build on an Apple Silicon Mac using native ARM64 Python.")
    if output.suffix != ".app":
        raise ValueError("The output path must end in .app.")
    if output.exists() or output.is_symlink():
        raise ValueError("The output already exists; choose a new path. Nothing was replaced.")
    if output == source or source in output.parents:
        raise ValueError("The output must be outside the source application.")
    if icon and not icon.is_file():
        raise ValueError("The supplied ICNS file does not exist.")
    info = validate_source(source)
    scratch = ROOT / ".build"
    scratch.mkdir(exist_ok=True)
    cache = scratch / "swift-module-cache"
    output.parent.mkdir(parents=True, exist_ok=True)
    print("Copying the vendor application. The source will remain unchanged.", flush=True)
    shutil.copytree(source, output, symlinks=True)
    contents = output / "Contents"
    macos = contents / "MacOS"
    resources = contents / "Resources"
    os.rename(macos / "Joplin", macos / "JoplinCore")
    run("/usr/bin/xcrun", "swiftc", "-O", "-target", "arm64-apple-macos11.0",
        "-module-cache-path", cache, ROOT / "src/main.swift", "-o", macos / "Joplin")

    original_icon = resources / info.get("CFBundleIconFile", "icon.icns")
    if not original_icon.suffix:
        original_icon = original_icon.with_suffix(".icns")
    destination_icon = resources / "icon.icns"
    if icon:
        shutil.copy2(icon, destination_icon)
    else:
        run("/usr/bin/xcrun", "swift", "-module-cache-path", cache,
            ROOT / "src/darken-icon.swift", original_icon, scratch / "dark-icon")
        shutil.copy2(scratch / "dark-icon/icon.icns", destination_icon)

    info.update(CFBundleIdentifier=BUNDLE_ID, CFBundleName="Joplin",
                CFBundleDisplayName="Joplin", CFBundleExecutable="Joplin",
                CFBundleIconFile="icon.icns", LSUIElement=False)
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    signing = ["/usr/bin/codesign", "--force", "--sign", "-", "--options", "runtime",
               "--entitlements", ROOT / "src/entitlements.plist"]
    # Native addons need their own signatures. Deep signing covers Electron's
    # nested frameworks and helper applications in this pinned vendor bundle.
    for addon in sorted(contents.rglob("*.node")):
        run(*signing, addon)
    run(*signing, "--deep", output)
    run(*signing, "--identifier", BUNDLE_ID, macos / "JoplinCore")
    # Seal the explicitly signed core without signing nested code again.
    run(*signing, output)
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", output)
    print(f"\nBuilt and signature-verified: {output}")
    print("Move this final copy to ~/Applications before granting Keychain access.")
    print("The build did not launch Joplin, access credentials, or change profiles or the Dock.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Unmodified Joplin 3.5.5 ARM64 .app from its DMG")
    parser.add_argument("--output", type=Path,
                        default=ROOT / "dist/Joplin-Institute-3.5.5.app")
    parser.add_argument("--icon", type=Path, help="Optional custom ICNS instead of recolouring the vendor icon")
    args = parser.parse_args()
    try:
        build(args.source.expanduser().resolve(), args.output.expanduser().resolve(),
              args.icon.expanduser().resolve() if args.icon else None)
    except (OSError, ValueError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
