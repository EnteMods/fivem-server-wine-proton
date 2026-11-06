#!/usr/bin/env python3
"""Audit the exact pinned Gitlink checkout without resetting valid worktrees."""
import argparse
import json
import os
import subprocess
from pathlib import Path

EXPECTED_SOURCE = "88a413835e9d7f56633f249880a13f42297153a2"
EXPECTED_GITLINKS = 174


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args], stderr=subprocess.PIPE)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--repair-empty", action="store_true")
    args = parser.parse_args()
    root = args.source.resolve(strict=True)
    if git(root, "rev-parse", "HEAD").decode().strip() != EXPECTED_SOURCE:
        raise SystemExit("Source revision differs from pinned commit")
    lines = git(root, "submodule", "status", "--recursive").decode().splitlines()
    if len(lines) != EXPECTED_GITLINKS:
        raise SystemExit(f"Expected {EXPECTED_GITLINKS} recursive Gitlinks, got {len(lines)}")
    repaired = []
    missing_repaired = 0
    for line in lines:
        if len(line) < 42 or line[0] != " ":
            raise SystemExit("Uninitialized or mismatched submodule: " + line[:120])
        expected = line[1:41]
        path = line[42:].split(" (", 1)[0]
        module = root / path
        if git(module, "rev-parse", "HEAD").decode().strip() != expected:
            raise SystemExit("Submodule HEAD mismatch: " + path)
        tracked = git(module, "ls-files", "-z")
        head_tree = git(module, "ls-tree", "-r", "--name-only", "-z", "HEAD")
        if head_tree and not tracked:
            if not args.repair_empty:
                raise SystemExit("Empty worktree at pinned HEAD: " + path)
            git(module, "restore", "--source=HEAD", "--staged", "--worktree", "--", ".")
            if not git(module, "ls-files", "-z"):
                raise SystemExit("Could not restore empty worktree: " + path)
            repaired.append(path)
            tracked = git(module, "ls-files", "-z")
        missing = [name for name in tracked.decode().split("\0") if name
                   and not os.path.lexists(module / name)]
        if missing:
            if not args.repair_empty:
                raise SystemExit("Missing tracked paths: " + path)
            git(module, "restore", "--source=HEAD", "--worktree", "--", *missing)
            if any(not os.path.lexists(module / name) for name in missing):
                raise SystemExit("Could not restore tracked paths: " + path)
            missing_repaired += len(missing)
    print(json.dumps({"source_revision": EXPECTED_SOURCE,
                      "recursive_gitlinks": len(lines),
                      "empty_worktrees_repaired": repaired,
                      "missing_tracked_paths_repaired": missing_repaired}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
