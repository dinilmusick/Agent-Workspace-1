#!/usr/bin/env python3
"""Install, validate and start a checked-out React/TypeScript project."""
import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = (ROOT / "workspaces" / "target").resolve()
ARTIFACTS = ROOT / "artifacts" / "build"

def project_dir(value):
    candidate = (TARGET / value).resolve()
    if candidate != TARGET and TARGET not in candidate.parents:
        raise SystemExit("project path must remain inside workspaces/target")
    if not (candidate / "package.json").is_file():
        raise SystemExit(f"package.json not found in {candidate}")
    return candidate

def package_manager(path):
    if (path / "pnpm-lock.yaml").exists():
        return ["corepack", "pnpm"]
    if (path / "yarn.lock").exists():
        return ["corepack", "yarn"]
    if (path / "package-lock.json").exists() or (path / "npm-shrinkwrap.json").exists():
        return ["npm"]
    return ["npm"]

def run(command, cwd, log_name):
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (ARTIFACTS / log_name).write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    if result.returncode:
        raise SystemExit(result.returncode)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["prepare", "start"])
    parser.add_argument("--project-path", default=".")
    args = parser.parse_args()
    path = project_dir(args.project_path)
    manager = package_manager(path)
    scripts = json.loads((path / "package.json").read_text(encoding="utf-8")).get("scripts", {})
    if args.action == "prepare":
        if manager[0] == "npm":
            install = manager + (["ci"] if (path / "package-lock.json").exists() or (path / "npm-shrinkwrap.json").exists() else ["install"])
        elif manager[1] == "pnpm":
            install = manager + ["install", "--frozen-lockfile"]
        else:
            install = manager + (["install", "--immutable"] if (path / ".yarnrc.yml").exists() else ["install", "--frozen-lockfile"])
        run(install, path, "install.log")
        if "build" in scripts:
            run(manager + ["run", "build"], path, "build.log")
        if "test" in scripts:
            test_args = manager + ["test"]
            if manager[1:] == ["pnpm"]:
                test_args += ["--", "--run"]
            elif manager[1:] == ["yarn"]:
                test_args += ["--run"]
            else:
                test_args += ["--", "--run"]
            run(test_args, path, "test.log")
    else:
        if "dev" not in scripts:
            raise SystemExit("No package.json 'dev' script; browser inspection cannot start this app automatically.")
        log_path = ARTIFACTS / "dev-server.log"
        ARTIFACTS.mkdir(parents=True, exist_ok=True)
        log = log_path.open("w", encoding="utf-8")
        command = manager + ["run", "dev", "--", "--host", "0.0.0.0", "--port", "4173"]
        process = subprocess.Popen(command, cwd=path, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        (ARTIFACTS / "dev-server.pid").write_text(str(process.pid), encoding="utf-8")
        print(f"Started dev server pid={process.pid}; log={log_path}")
if __name__ == "__main__":
    main()
