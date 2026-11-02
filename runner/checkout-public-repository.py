#!/usr/bin/env python3
"""Safely check out a public GitHub repository into the disposable workspaces area."""
import argparse
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "workspaces" / "target"
REPOSITORY = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
REF = re.compile(r"^[A-Za-z0-9_./-]+$")
COMMIT = re.compile(r"^[0-9a-fA-F]{7,40}$")

def git(*args):
    subprocess.run(["git", *args], check=True, cwd=ROOT)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True, help="Public GitHub repository in owner/name form")
    parser.add_argument("--ref", default="", help="Optional branch, tag, or commit SHA")
    args = parser.parse_args()
    if not REPOSITORY.fullmatch(args.repository) or ".." in args.repository:
        parser.error("repository must be a public GitHub owner/name")
    if args.ref and (not REF.fullmatch(args.ref) or args.ref.startswith("-") or ".." in args.ref):
        parser.error("ref contains unsupported characters")
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    if DESTINATION.exists():
        if DESTINATION.is_symlink():
            DESTINATION.unlink()
        else:
            shutil.rmtree(DESTINATION)
    repository_url = f"https://github.com/{args.repository}.git"
    if args.ref and not COMMIT.fullmatch(args.ref):
        git("clone", "--depth", "1", "--branch", args.ref, repository_url, str(DESTINATION))
    else:
        git("clone", "--depth", "1", repository_url, str(DESTINATION))
        if args.ref:
            subprocess.run(["git", "fetch", "--depth", "1", "origin", args.ref], check=True, cwd=DESTINATION)
            subprocess.run(["git", "checkout", "--detach", "FETCH_HEAD"], check=True, cwd=DESTINATION)
    print(f"Checked out {args.repository}@{args.ref or 'default branch'} into {DESTINATION.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
