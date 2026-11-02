#!/usr/bin/env python3
"""Safely check out a public GitHub repository into the disposable workspaces area."""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "workspaces" / "target"
REPOSITORY = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
REF = re.compile(r"^[A-Za-z0-9_./-]+$")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True, help="Public GitHub repository in owner/name form")
    parser.add_argument("--ref", default="", help="Optional branch, tag, or commit-ish")
    args = parser.parse_args()
    if not REPOSITORY.fullmatch(args.repository) or ".." in args.repository:
        parser.error("repository must be a public GitHub owner/name")
    if args.ref and (not REF.fullmatch(args.ref) or args.ref.startswith("-") or ".." in args.ref):
        parser.error("ref contains unsupported characters")
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    if DESTINATION.exists():
        import shutil
        shutil.rmtree(DESTINATION)
    command = ["git", "clone", "--depth", "1"]
    if args.ref:
        command += ["--branch", args.ref]
    command += [f"https://github.com/{args.repository}.git", str(DESTINATION)]
    subprocess.run(command, check=True, cwd=ROOT)
    print(f"Checked out {args.repository}@{args.ref or 'default branch'} into {DESTINATION.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
