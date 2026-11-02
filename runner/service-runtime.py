#!/usr/bin/env python3
"""Supervise local full-stack services for an ephemeral inspection workspace."""
import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import urlopen

STOP = False

def write_state(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    temp.replace(path)

def free_port():
    with socket.socket() as server:
        server.bind(("127.0.0.1", 0))
        return server.getsockname()[1]

def inside(root, value):
    path = (root / value).resolve()
    if path != root and root not in path.parents:
        raise ValueError(f"path escapes project root: {value}")
    return path

def expand(value, services):
    result = str(value)
    for name, port in services.items():
        result = result.replace(f"${{service.{name}.port}}", str(port or ""))
        result = result.replace(f"${{service.{name}.url}}", f"http://127.0.0.1:{port}" if port else "")
    return result

def load_services(manifest_path, root):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != 1 or not isinstance(manifest.get("services"), list) or not manifest["services"]:
        raise ValueError("services manifest requires version=1 and a non-empty services array")
    configs, ports = {}, {}
    for item in manifest["services"]:
        name = item.get("id")
        command = item.get("command")
        if not isinstance(name, str) or not name.replace("-", "").replace("_", "").isalnum() or name in configs:
            raise ValueError(f"invalid or duplicate service id: {name}")
        if not isinstance(command, list) or not command or not all(isinstance(part, str) for part in command):
            raise ValueError(f"{name}: command must be a non-empty argv array; shell commands are not accepted")
        cwd = inside(root, item.get("cwd", "."))
        if not cwd.is_dir():
            raise ValueError(f"{name}: working directory does not exist: {cwd}")
        health = item.get("healthcheck", {"type": "process"})
        if health.get("type", "process") in ("http", "tcp") and item.get("port") is None:
            raise ValueError(f"{name}: HTTP/TCP healthchecks require a port")
        port = item.get("port")
        ports[name] = free_port() if port == 0 else port
        configs[name] = {**item, "cwd_path": cwd, "healthcheck": health}
    for name, item in configs.items():
        item["command"] = [expand(part, ports) for part in item["command"]]
        item["env"] = {key: expand(value, ports) for key, value in item.get("env", {}).items()}
    return configs, ports

def healthy(item):
    process = item.get("process")
    if process is None or process.poll() is not None:
        return False
    check = item["config"].get("healthcheck", {"type": "process"})
    kind = check.get("type", "process")
    if kind == "process":
        return True
    host, port = check.get("host", "127.0.0.1"), item["port"]
    try:
        if kind == "tcp":
            with socket.create_connection((host, port), timeout=0.5):
                return True
        if kind == "http":
            url = f"http://{host}:{port}{check.get('path', '/')}"
            with urlopen(url, timeout=0.5) as response:
                return 200 <= response.status < 400
    except Exception:
        return False
    raise ValueError(f"unsupported healthcheck type: {kind}")

def launch(name, item, state, state_path):
    config = item["config"]
    env = os.environ.copy()
    env.update(config.get("env", {}))
    if item["port"] is not None:
        env[config.get("port_env", "PORT")] = str(item["port"])
    if config.get("host_env"):
        env[config["host_env"]] = config.get("host", "127.0.0.1")
    log_path = Path(state["services"][name]["log"])
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("ab", buffering=0) as log:
        process = subprocess.Popen(config["command"], cwd=config["cwd_path"], env=env,
            stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    item["process"] = process
    entry = state["services"][name]
    entry.update({"pid": process.pid, "status": "starting", "health": "starting"})
    write_state(state_path, state)

def restart_allowed(config, code):
    policy = config.get("restart", {}).get("policy", "never")
    return policy == "always" or (policy == "on-failure" and code != 0)

def stop_process(process, grace):
    if process is None or process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=2)

def supervise(manifest, root, state_dir, startup_timeout):
    global STOP
    signal.signal(signal.SIGTERM, lambda *_: setattr_signal())
    signal.signal(signal.SIGINT, lambda *_: setattr_signal())
    state_path = state_dir / "state.json"
    configs, ports = load_services(manifest, root)
    runtime = {name: {"config": config, "port": ports[name], "process": None,
        "restarts": 0, "failures": 0, "next_check": 0.0} for name, config in configs.items()}
    state = {"pid": os.getpid(), "status": "starting", "services": {
        name: {"pid": None, "port": item["port"], "status": "starting", "health": "starting",
            "restart_count": 0, "log": str(state_dir / f"{name}.log")} for name, item in runtime.items()}}
    write_state(state_path, state)
    try:
        for name, item in runtime.items():
            launch(name, item, state, state_path)
        deadline = time.monotonic() + startup_timeout
        while time.monotonic() < deadline and not STOP:
            ready = True
            for name, item in runtime.items():
                process = item["process"]
                if process.poll() is not None:
                    config = item["config"]
                    code = process.returncode
                    restart = config.get("restart", {})
                    if restart_allowed(config, code) and item["restarts"] < restart.get("max_restarts", 0):
                        item["restarts"] += 1
                        state["services"][name]["restart_count"] = item["restarts"]
                        time.sleep(restart.get("delay_seconds", 0.2))
                        launch(name, item, state, state_path)
                    else:
                        raise RuntimeError(f"{name} exited during startup with code {code}")
                if healthy(item):
                    state["services"][name]["status"] = "ready"
                    state["services"][name]["health"] = "healthy"
                else:
                    ready = False
            write_state(state_path, state)
            if ready:
                state["status"] = "ready"
                write_state(state_path, state)
                break
            time.sleep(0.2)
        if state["status"] != "ready":
            if STOP:
                state["status"] = "stopped"
                return
            raise TimeoutError(f"services did not become ready within {startup_timeout}s")
        while not STOP:
            now = time.monotonic()
            for name, item in runtime.items():
                config = item["config"]
                process = item["process"]
                entry = state["services"][name]
                interval = config.get("healthcheck", {}).get("interval_seconds", 2)
                if process.poll() is not None:
                    code = process.returncode
                    restart = config.get("restart", {})
                    if restart_allowed(config, code) and item["restarts"] < restart.get("max_restarts", 0):
                        item["restarts"] += 1
                        time.sleep(restart.get("delay_seconds", 0.2))
                        launch(name, item, state, state_path)
                        entry["restart_count"] = item["restarts"]
                        item["failures"] = 0
                    else:
                        raise RuntimeError(f"{name} exited unexpectedly with code {code}")
                elif now >= item["next_check"]:
                    item["next_check"] = now + interval
                    if healthy(item):
                        item["failures"] = 0
                        entry["health"] = "healthy"
                    else:
                        item["failures"] += 1
                        entry["health"] = "unhealthy"
                        if item["failures"] >= config.get("healthcheck", {}).get("failure_threshold", 3):
                            restart = config.get("restart", {})
                            if restart_allowed(config, 1) and item["restarts"] < restart.get("max_restarts", 0):
                                stop_process(process, config.get("shutdown_grace_seconds", 5))
                                item["restarts"] += 1
                                launch(name, item, state, state_path)
                                entry["restart_count"] = item["restarts"]
                                item["failures"] = 0
                            else:
                                raise RuntimeError(f"{name} failed its healthcheck")
            write_state(state_path, state)
            time.sleep(0.25)
        state["status"] = "stopping"
    except Exception as error:
        state["status"] = "failed"
        state["error"] = str(error)
    finally:
        for item in runtime.values():
            stop_process(item["process"], item["config"].get("shutdown_grace_seconds", 5))
        if state["status"] == "stopping":
            state["status"] = "stopped"
        write_state(state_path, state)
    return 1 if state["status"] == "failed" else 0

def setattr_signal():
    global STOP
    STOP = True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["start", "stop", "status", "supervise"])
    parser.add_argument("--manifest", type=Path, default=Path(".agent-workspace/services.json"))
    parser.add_argument("--project-root", type=Path, default=Path("."))
    parser.add_argument("--state-dir", type=Path, default=Path("artifacts/services"))
    parser.add_argument("--startup-timeout", type=float, default=60)
    parser.add_argument("--stop-timeout", type=float, default=15)
    args = parser.parse_args()
    state_dir = args.state_dir.resolve()
    state_path = state_dir / "state.json"
    if args.action == "supervise":
        return supervise(args.manifest.resolve(), args.project_root.resolve(), state_dir, args.startup_timeout)
    if args.action == "status":
        print(state_path.read_text(encoding="utf-8") if state_path.exists() else "{}")
        return 0
    if args.action == "stop":
        if not state_path.exists():
            print("No service runtime state; nothing to stop.")
            return 0
        state = json.loads(state_path.read_text(encoding="utf-8"))
        pid = state.get("pid")
        if pid:
            try: os.kill(pid, signal.SIGTERM)
            except ProcessLookupError: pass
        deadline = time.monotonic() + args.stop_timeout
        while time.monotonic() < deadline:
            current = json.loads(state_path.read_text(encoding="utf-8"))
            if current.get("status") in ("stopped", "failed"):
                print(json.dumps(current, indent=2))
                return 0
            time.sleep(0.1)
        raise SystemExit("service supervisor did not stop before timeout")
    state_dir.mkdir(parents=True, exist_ok=True)
    if state_path.exists():
        old = json.loads(state_path.read_text(encoding="utf-8"))
        if old.get("pid"):
            try:
                os.kill(old["pid"], 0)
                raise SystemExit("service supervisor already running; stop it before starting again")
            except ProcessLookupError:
                pass
    log = (state_dir / "supervisor.log").open("ab")
    process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "supervise",
        "--manifest", str(args.manifest.resolve()), "--project-root", str(args.project_root.resolve()),
        "--state-dir", str(state_dir), "--startup-timeout", str(args.startup_timeout)],
        stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    log.close()
    deadline = time.monotonic() + args.startup_timeout + 5
    while time.monotonic() < deadline:
        if state_path.exists():
            state = json.loads(state_path.read_text(encoding="utf-8"))
            if state.get("status") == "ready":
                print(json.dumps(state, indent=2))
                return 0
            if state.get("status") == "failed":
                print(json.dumps(state, indent=2), file=sys.stderr)
                return 1
        if process.poll() is not None:
            break
        time.sleep(0.1)
    try: os.kill(process.pid, signal.SIGTERM)
    except ProcessLookupError: pass
    raise SystemExit("service supervisor failed to reach ready state")

if __name__ == "__main__":
    raise SystemExit(main() or 0)
