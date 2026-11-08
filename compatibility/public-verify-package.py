#!/usr/bin/env python3
"""Read-only SHA, component, resource and ELF closure check for a package tree."""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

EXPECTED_RESOURCES = (
    "mapmanager", "chat", "spawnmanager",
    "basic-gamemode", "fivem-map-hipster",
)


def readelf(path: Path, option: str) -> str:
    p = subprocess.run(["readelf", option, str(path)], text=True,
                       capture_output=True)
    if p.returncode:
        raise RuntimeError(f"readelf failed for {path.name}: {p.stderr[:120]}")
    return p.stdout


def rpath_dirs(elf: Path, dynamic: str) -> list[Path]:
    result = []
    for value in re.findall(r"\((?:RUNPATH|RPATH)\).*?\[([^\]]+)\]", dynamic):
        for entry in value.split(":"):
            expanded = entry.replace("${ORIGIN}", str(elf.parent))
            expanded = expanded.replace("$ORIGIN", str(elf.parent))
            if not expanded.startswith("/"):
                raise SystemExit("Unsupported relative ELF search path: " + elf.name)
            result.append(Path(expanded))
    return result


def in_loader_paths(name: str, search_dirs: list[Path], package_root: Path) -> bool:
    rootfs = (package_root / "alpine").resolve()
    for directory in search_dirs:
        candidate = directory / name
        if not candidate.exists():
            continue
        resolved = candidate.resolve()
        if resolved == rootfs or rootfs in resolved.parents:
            return True
    return False


def account_remnants(etc: Path) -> list[str]:
    found = []
    for prefix in ("shadow", "gshadow", "passwd", "group"):
        for path in etc.glob(prefix + "*"):
            if prefix in ("passwd", "group") and path.name == prefix:
                continue
            found.append(path.name)
    return sorted(set(found))


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: public-verify-package.py /absolute/package")
    root = Path(sys.argv[1]).resolve(strict=True)
    manifest = root / "SHA256SUMS"
    if not manifest.is_file():
        raise SystemExit("SHA256SUMS missing")
    subprocess.run(["sha256sum", "-c", "SHA256SUMS"], cwd=root,
                   stdout=subprocess.DEVNULL, check=True)
    recorded = set()
    for line in manifest.read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise SystemExit("Invalid SHA256SUMS line")
        recorded.add(match.group(2).removeprefix("./"))
    actual = {
        str(path.relative_to(root))
        for path in root.rglob("*")
        if path.is_file() and not path.is_symlink()
        and path.name != "SHA256SUMS"
    }
    if recorded != actual:
        raise SystemExit("SHA256SUMS does not cover exactly the regular files")

    server = root / "alpine/opt/cfx-server"
    original = json.loads((server / "components.original.json").read_text())
    current = json.loads((server / "components.json").read_text())
    if len(original) != 26 or original.count("svadhesive") != 1:
        raise SystemExit("Unexpected original component manifest")
    if current != [name for name in original if name != "svadhesive"]:
        raise SystemExit("Package manifest changed beyond documented WSL step")
    if (server / "libsvadhesive.so").exists():
        raise SystemExit("Built svadhesive present while omitted from manifest")
    if (server / "citizen/system_resources/monitor").exists():
        raise SystemExit("Separate Monitor artifact is not in this package")
    for name in EXPECTED_RESOURCES:
        found = list((server / "resources").rglob(name))
        if name == "chat":
            found += [server / "citizen/system_resources/chat"]
        if not any(path.is_dir() for path in found):
            raise SystemExit(f"Missing resource: {name}")
    for name in ("chat", "yarn", "webpack"):
        if not (server / "citizen/system_resources" / name).is_dir():
            raise SystemExit(f"Missing public system resource: {name}")
    for name in ("chat.js", "ui.html", "index.css"):
        if not (server / "citizen/system_resources/chat/dist" / name).is_file():
            raise SystemExit(f"Missing compiled Chat asset: {name}")

    cfg = (server / "example-lan.cfg").read_text()
    if not cfg.startswith("sv_lan true\n") or "127.0.0.1:30120" not in cfg:
        raise SystemExit("Example config is not a private loopback LAN example")
    if re.search(r"(?i)(license|password|token|secret|api.?key)", cfg):
        raise SystemExit("Example config contains a credential directive")
    if (root / "run.sh").is_file() is False:
        raise SystemExit("Upstream launcher missing")
    if not (server / "ld-musl-x86_64.so.1").is_file():
        raise SystemExit("Packaged musl loader missing")
    if not (root / "UPSTREAM-LICENSES/CitizenFX-LICENSE").is_file():
        raise SystemExit("Upstream source license missing")
    if not (root / "SOURCE_PROVENANCE.txt").is_file():
        raise SystemExit("Source provenance missing")
    for forbidden in ("root", "tmp", "src", "fivem-private", "builds", "utils"):
        if (root / "alpine" / forbidden).exists():
            raise SystemExit(f"Build-only rootfs directory retained: {forbidden}")
    etc = root / "alpine/etc"
    remnants = account_remnants(etc)
    if remnants:
        raise SystemExit("Account backup file retained: " + ", ".join(remnants))
    if (root / "alpine/var/cache/apk").exists() or (server / "cache").exists():
        raise SystemExit("APK or server build cache retained")
    if list((root / "alpine").rglob("*.apk")):
        raise SystemExit("APK package retained in runtime copy")

    fxserver = server / "FXServer"
    if fxserver.read_bytes()[:4] != b"\x7fELF":
        raise SystemExit("FXServer is not an ELF")
    interp = readelf(fxserver, "-l")
    if "/lib/ld-musl-x86_64.so.1" not in interp:
        raise SystemExit("Unexpected FXServer interpreter")
    if not (root / "alpine/lib/ld-musl-x86_64.so.1").exists():
        raise SystemExit("Rootfs interpreter missing")
    # The upstream server_proot launcher supplies these three rootfs paths.
    # FXServer's $ORIGIN RUNPATH supplies the top-level component directory.
    wrapper_dirs = [root / "alpine/usr/lib/v8", root / "alpine/lib",
                    root / "alpine/usr/lib"]
    main_dynamic = readelf(fxserver, "-d")
    main_dirs = rpath_dirs(fxserver, main_dynamic)
    needed = set()
    missing = []
    elf_count = 0
    for path in server.iterdir():
        if path.name != "FXServer" and not path.name.endswith(".so"):
            continue
        if not path.is_file() or path.is_symlink():
            continue
        with path.open("rb") as stream:
            if stream.read(4) != b"\x7fELF":
                continue
        elf_count += 1
        dynamic = readelf(path, "-d")
        search_dirs = wrapper_dirs + main_dirs + rpath_dirs(path, dynamic)
        for name in re.findall(r"Shared library: \[([^\]]+)\]", dynamic):
            needed.add(name)
            if not in_loader_paths(name, search_dirs, root):
                missing.append((path.name, name))
    if missing:
        raise SystemExit("ELF loader-path closure missing: " + str(missing))
    summary = {
        "package_regular_files": len(actual),
        "component_count": len(current),
        "top_level_elf_files": elf_count,
        "unique_top_level_needed_libraries": len(needed),
        "missing_loader_path_needed_libraries": 0,
        "nested_elf_and_dlopen_require_isolated_start_test": True,
        "resources_checked": list(EXPECTED_RESOURCES),
        "sha256_manifest_valid": True,
        "client_join_tested": False,
    }
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
