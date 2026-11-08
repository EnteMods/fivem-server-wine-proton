#!/usr/bin/env python3
"""Apply or verify the pinned V4/V5 public source overlay."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath

BASE_REVISION = "88a413835e9d7f56633f249880a13f42297153a2"
MANIFEST_SHA256 = "f4055900d3ab6765c0ea06863fdbff99ab4b363a515349c2272d5acbefe9a0fe"
BASE_SHA256 = {'code/components/citizen-scripting-node/include/UvLoopTimer.h': 'ab848e4e0df86b97dc76c19e32f605b04c62a187a800d1b0fbce4b77854cde40', 'code/components/citizen-scripting-node/src/UvLoopTimer.cpp': '1ba30504c5f5384d58bf7014e384ec577efb49aebadb244d1b99986968be37c9', 'code/components/citizen-server-impl/include/GameServer.h': '558a5664c5ee135eb8675d8a2c6e9b24fcad76849b114d6fd962af5b54c161eb', 'code/components/citizen-server-impl/include/GameServerComms.h': 'b3bd940e1f648f345fa6376f065acc733f2e4bf2fd8922ed06a7b43a7d0848e2', 'code/components/citizen-server-impl/include/InterruptibleNonTtyInput.h': None, 'code/components/citizen-server-impl/include/SvMainCallbackQueue.h': None, 'code/components/citizen-server-impl/src/GameServer.cpp': '1ac3fb2b3393bfff322787f011943c01aec90faf88ba08e80e223eb576cc19bc', 'code/components/citizen-server-impl/src/ResourceHttpHandler.cpp': 'f40da632807506a246ce5f6b40127c0e81a90727abd7712d17a3d906730f3d72', 'code/components/citizen-server-impl/src/ServerWatchdog.cpp': '3669e802ce5252b4d61600a8c4641b0662a340f6e9b8be9845c70407b86f35de', 'code/components/citizen-server-impl/src/TerminalInput.cpp': '9dda33a3fdf2595f3231fc0d77c08cfc97f973948c52161e371468edcdbe5564', 'code/components/citizen-server-instance/include/ServerShutdownLifecycle.h': None, 'code/components/citizen-server-instance/src/ServerInstanceBase.cpp': '191a0018fe7a52841155bf7412efc17aa99217de9b598f37c84df9175f9722a2', 'code/components/citizen-server-main/include/ServerInstance.h': '91ccd723c330ebcd1ee09df96926419ee5ac891e409343ee12b9a6a30e0d7629', 'code/components/citizen-server-main/src/ServerInstance.cpp': '82cf6d8d5759fbcccfd76cb274a4112b79f32b580be8442e291b12fa9223138b', 'code/components/net-tcp-server/include/UvLoopHolder.h': '5f5c58956c10262b331c2bb69c8685b44cdc3768f3a3e0fb59737899a9720765', 'code/components/net-tcp-server/src/UvLoopHolder.cpp': 'f7fdb06d060b9c3c64a5e54a4f84699f6e1247316cc45f9f4e72e4e5acb1376d', 'code/components/citizen-resources-core/src/EventReassemblyComponent.cpp': 'c9b53ced291d6976eaa7fe742e923935ba83e5449c0a48c690f317fc355f1d62', 'code/components/citizen-server-impl/src/InitConnectMethod.cpp': '19171ad4b7eed2d2348b44cd85223b3d91ca91828129ad4a2a62740ad966ed13', 'code/components/citizen-server-net/src/HttpServerManager.cpp': '82cb0d847a0d62733fc64c21a61fdb552e0cb955275de18127adbe3869883298', 'code/components/devcon/src/DevConServer.cpp': 'f132c01653d77b67aad529441001cc8c70aa5a3a664bce9eae8b78a90974067d', 'code/shared/state/RlMessageBuffer.h': '0f9770b1f88649df909fcaec37d0c1cadd1f6e4d98b9c320bbac7b38354ab85b', 'code/tests/server/TestEventReassembly.cpp': 'e8d0aa6e77139a97fe7543083edfe1417283353ba9af700351fa32c6c549d33b', 'code/tests/shared/TestMessageBuffer.cpp': 'c2b6f7fd82f905df088d43a7dcf5802421949b7d75d4fc8dcd4e300eced90989'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_path(root, rel):
    path = root
    for part in PurePosixPath(rel).parts:
        path = path / part
        if path.is_symlink():
            raise SystemExit("Symlink in source path: " + rel)
    return path


def read_manifest(path):
    data = path.read_bytes()
    if digest(data) != MANIFEST_SHA256:
        raise SystemExit("Source overlay manifest hash mismatch")
    entries = {}
    for line in data.decode("ascii").splitlines():
        hash_value, sep, rel = line.partition("  ")
        p = PurePosixPath(rel)
        if (not sep or len(hash_value) != 64 or any(c not in "0123456789abcdef" for c in hash_value)
                or not rel.startswith("code/") or p.is_absolute() or ".." in p.parts
                or str(p) != rel or p.suffix not in (".cpp", ".h") or rel in entries):
            raise SystemExit("Invalid source overlay manifest entry")
        entries[rel] = hash_value
    if set(entries) != set(BASE_SHA256) or len(entries) != 23:
        raise SystemExit("Unexpected source overlay path set")
    return entries


def read_file(path, expected, rel):
    if not path.is_file():
        raise SystemExit("Missing source file: " + rel)
    data = path.read_bytes()
    if digest(data) != expected:
        raise SystemExit("Source hash mismatch: " + rel)
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        raise SystemExit("Source is not UTF-8: " + rel)
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("apply", "verify"))
    parser.add_argument("manifest", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("--overlay", type=Path)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    entries = read_manifest(args.manifest)
    if args.mode == "verify":
        for rel, expected in entries.items():
            read_file(checked_path(source, rel), expected, rel)
        return
    if args.overlay is None or args.receipt is None:
        parser.error("apply requires --overlay and --receipt")
    overlay = args.overlay.resolve(strict=True)
    if source == overlay or source in overlay.parents or overlay in source.parents:
        raise SystemExit("Source and overlay roots must be separate")
    if os.path.lexists(args.receipt):
        raise SystemExit("Receipt already exists")
    replacements = {}
    for rel, expected in entries.items():
        replacements[rel] = read_file(checked_path(overlay, rel), expected, rel)
        dest = checked_path(source, rel)
        base = BASE_SHA256[rel]
        if base is None:
            if os.path.lexists(dest):
                raise SystemExit("New source path already exists: " + rel)
        else:
            read_file(dest, base, rel)
    for rel, data in replacements.items():
        dest = checked_path(source, rel)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    receipt = {"schema": "v4-v5-source-overlay-v1", "base_revision": BASE_REVISION,
               "manifest_sha256": MANIFEST_SHA256,
               "files": [{"path": rel, "base_sha256": BASE_SHA256[rel], "sha256": expected}
                         for rel, expected in sorted(entries.items())]}
    with args.receipt.open("x", encoding="utf-8") as output:
        json.dump(receipt, output, indent=2, sort_keys=True)
        output.write("\n")


if __name__ == "__main__":
    main()
