#!/usr/bin/env python3
"""Prepare and run checked-out React/TypeScript applications and their services."""
import argparse
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = (ROOT / "workspaces" / "target").resolve()
ARTIFACTS = ROOT / "artifacts" / "build"
SERVICE_RUNTIME = ROOT / "runner" / "service-runtime.py"
SERVICE_STATE = ROOT / "artifacts" / "services"

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
    return ["npm"]

def run(command, cwd, log_name):
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, env={**os.environ, "CI": "true"})
    (ARTIFACTS / log_name).write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    if result.returncode:
        raise SystemExit(result.returncode)

def service_runtime(action, project, timeout=60):
    manifest = project / ".agent-workspace" / "services.json"
    command = [sys.executable, str(SERVICE_RUNTIME), action, "--project-root", str(project),
        "--state-dir", str(SERVICE_STATE), "--startup-timeout", str(timeout)]
    if manifest.is_file():
        command += ["--manifest", str(manifest)]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode:
        raise SystemExit(result.returncode)

def stop_single_server():
    pid_file = ARTIFACTS / "dev-server.pid"
    if not pid_file.exists():
        print("No single-server process to stop.")
        return
    pid = int(pid_file.read_text(encoding="utf-8"))
    try:
        os.killpg(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            os.killpg(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.1)
    else:
        try:
            os.killpg(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    pid_file.unlink(missing_ok=True)
    print(f"Stopped application process group {pid}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["prepare", "start", "stop", "status"])
    parser.add_argument("--project-path", default=".")
    parser.add_argument("--startup-timeout", type=float, default=60)
    args = parser.parse_args()
    path = project_dir(args.project_path)
    manifest = path / ".agent-workspace" / "services.json"
    if args.action == "prepare":
        manager = package_manager(path)
        package = json.loads((path / "package.json").read_text(encoding="utf-8"))
        scripts = package.get("scripts", {})
        if manager[0] == "npm":
            install = manager + (["ci", "--no-audit", "--no-fund"] if (path / "package-lock.json").exists() or (path / "npm-shrinkwrap.json").exists() else ["install", "--no-audit", "--no-fund"])
        elif manager[1] == "pnpm":
            install = manager + ["install", "--frozen-lockfile"]
        else:
            install = manager + (["install", "--immutable"] if (path / ".yarnrc.yml").exists() else ["install", "--frozen-lockfile"])
        run(install, path, "install.log")
        if "build" in scripts:
            run(manager + ["run", "build"], path, "build.log")
        if "test" in scripts:
            run(manager + ["test"], path, "test.log")
    elif args.action == "start":
        if manifest.is_file():
            service_runtime("start", path, args.startup_timeout)
            return
        manager = package_manager(path)
        package = __import__("json").loads((path / "package.json").read_text(encoding="utf-8"))
        scripts = package.get("scripts", {})
        dependencies = {**package.get("dependencies", {}), **package.get("devDependencies", {})}
        start_script = "dev" if "dev" in scripts else ("start" if "start" in scripts else ("preview" if "preview" in scripts else None))
        if not start_script:
            raise SystemExit("No package.json dev, start, or preview script; cannot start browser inspection.")
        command = manager + ["run", start_script]
        env = {**os.environ, "HOST": "0.0.0.0", "HOSTNAME": "0.0.0.0", "PORT": "4173", "CI": "true"}
        if "next" in dependencies:
            command += ["--", "--hostname", "0.0.0.0", "--port", "4173"]
        elif "vite" in dependencies or start_script == "preview":
            command += ["--", "--host", "0.0.0.0", "--port", "4173"]
        ARTIFACTS.mkdir(parents=True, exist_ok=True)
        with (ARTIFACTS / "dev-server.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(command, cwd=path, env=env, stdout=log, stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL, start_new_session=True)
        (ARTIFACTS / "dev-server.pid").write_text(str(process.pid), encoding="utf-8")
        print(f"Started {start_script} server pid={process.pid}; log={ARTIFACTS / 'dev-server.log'}")
    elif args.action == "stop":
        if manifest.is_file() or (SERVICE_STATE / "state.json").exists():
            service_runtime("stop", path, args.startup_timeout)
        else:
            stop_single_server()
    else:
        if manifest.is_file() or (SERVICE_STATE / "state.json").exists():
            service_runtime("status", path, args.startup_timeout)
        else:
            pid_file = ARTIFACTS / "dev-server.pid"
            print(f"single_server_pid={pid_file.read_text().strip()}" if pid_file.exists() else "stopped")

if __name__ == "__main__":
    main()
