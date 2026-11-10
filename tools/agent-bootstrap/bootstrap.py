#!/usr/bin/env python3
"""Deterministic Agent Workspace bootstrap and local execution preflight."""
from __future__ import annotations
import argparse, json, shutil, subprocess, sys
from pathlib import Path

WORKSPACE_URL = "https://github.com/dinilmusick/Agent-Workspace-1.git"

def run(command, cwd=None):
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)

def command_exists(name): return shutil.which(name) is not None

def repo_root(path):
    result = run(["git", "rev-parse", "--show-toplevel"], path)
    return Path(result.stdout.strip()) if result.returncode == 0 else None

def build_commands(root):
    commands = []
    package = root / "package.json"
    if package.exists():
        try:
            data = json.loads(package.read_text())
            scripts = data.get("scripts", {})
            for name in ("build", "typecheck", "lint", "test"):
                if name in scripts: commands.append(["npm", "run", name])
        except (OSError, json.JSONDecodeError):
            pass
    for candidate in ("build.sh", "build.py", "Makefile"):
        if (root / candidate).exists():
            commands.append(["bash", candidate] if candidate == "build.sh" else
                            [sys.executable, candidate] if candidate == "build.py" else ["make"])
    return commands

def plan(args):
    root = repo_root(Path.cwd())
    workspace = Path(args.workspace).expanduser().resolve()
    result = {
        "workspace_repo": "dinilmusick/Agent-Workspace-1",
        "workspace_path": str(workspace),
        "workspace_present": workspace.exists(),
        "current_repository": str(root) if root else None,
        "git_available": command_exists("git"),
        "target_repository": args.repository,
        "target_ref": args.ref,
        "local_runtime": True,
        "build_commands": build_commands(root) if root else [],
        "next": []
    }
    if not result["git_available"]:
        result["next"].append("Install git or use the Agent-Workspace GitHub Actions fallback.")
    elif not workspace.exists():
        result["next"].append("Clone Agent-Workspace-1 into this runtime before repository work.")
    if args.repository:
        result["next"].append("Attempt a direct target clone; if a private clone fails, use Agent-Workspace-1 private-repository tooling.")
    if result["build_commands"]:
        result["next"].append("Run every discovered repository build/quality script before completion.")
    result["next"].append("Capture command output as evidence and independently verify resulting behavior.")
    print(json.dumps(result, indent=2)); return 0

def prepare(args):
    if not command_exists("git"):
        print("ERROR: git is required for local bootstrap.", file=sys.stderr); return 2
    workspace = Path(args.workspace).expanduser().resolve()
    workspace.parent.mkdir(parents=True, exist_ok=True)
    if not (workspace / ".git").exists():
        result = run(["git", "clone", "--depth", "1", "--branch", "main", WORKSPACE_URL, str(workspace)])
        if result.returncode:
            print(result.stderr, file=sys.stderr); return result.returncode
    if args.repository:
        target = Path(args.target_path or (workspace / "clones" / args.repository.split("/")[-1])).resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        if not (target / ".git").exists():
            clone = run(["git", "clone", "--depth", "1", "--branch", args.ref, args.repository, str(target)])
            if clone.returncode:
                print("DIRECT_CLONE_FAILED: use Agent-Workspace private-repository tooling for authorized private targets.", file=sys.stderr)
                print(clone.stderr, file=sys.stderr); return 3
        else:
            run(["git", "fetch", "--depth", "1", "origin", args.ref], target)
            run(["git", "checkout", args.ref], target)
        print(json.dumps({"workspace":str(workspace),"target":str(target),"ref":args.ref,"build_commands":build_commands(target)}, indent=2))
    else:
        print(json.dumps({"workspace":str(workspace),"target":None}, indent=2))
    return 0

def main():
    parser = argparse.ArgumentParser(description="Bootstrap Agent Workspace for local agent execution.")
    sub = parser.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--workspace", default=".agent-workspace")
    common.add_argument("--repository")
    common.add_argument("--ref", default="main")
    common.add_argument("--target-path")
    for name, func in (("plan", plan), ("prepare", prepare)):
        p = sub.add_parser(name, parents=[common]); p.set_defaults(func=func)
    return parser.parse_args().func(parser.parse_args())

if __name__ == "__main__":
    raise SystemExit(main())
