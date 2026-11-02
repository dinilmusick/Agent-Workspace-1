#!/usr/bin/env python3
"""Execute a validated task manifest and emit machine-readable evidence."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MAX_TIMEOUT = 1800
MAX_OUTPUT_CHARS = 100_000


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_task(task_path: str) -> tuple[dict[str, Any], Path]:
    candidate = (ROOT / task_path).resolve()
    if not candidate.is_relative_to(ROOT):
        raise ValueError("task_file must resolve inside the repository workspace")
    if not candidate.is_file() or candidate.suffix.lower() != ".json":
        raise ValueError("task_file must be an existing JSON file")
    task = json.loads(candidate.read_text(encoding="utf-8"))
    if not isinstance(task, dict) or task.get("version") != 1:
        raise ValueError("unsupported task manifest; expected object with version=1")
    command = task.get("command")
    if not isinstance(command, list) or not command or not all(isinstance(x, str) and x for x in command):
        raise ValueError("command must be a non-empty array of non-empty strings")
    if len(command) > 128 or any(len(x) > 4096 for x in command):
        raise ValueError("command exceeds supported argument limits")
    timeout = task.get("timeout_seconds", 300)
    if not isinstance(timeout, int) or isinstance(timeout, bool) or not 1 <= timeout <= MAX_TIMEOUT:
        raise ValueError(f"timeout_seconds must be an integer from 1 to {MAX_TIMEOUT}")
    cwd_value = task.get("cwd", ".")
    if not isinstance(cwd_value, str):
        raise ValueError("cwd must be a repository-relative path")
    cwd = (ROOT / cwd_value).resolve()
    if not cwd.is_relative_to(ROOT) or not cwd.is_dir():
        raise ValueError("cwd must be an existing directory inside the repository")
    env = task.get("env", {})
    if not isinstance(env, dict) or len(env) > 32:
        raise ValueError("env must be an object with at most 32 entries")
    for key, value in env.items():
        if not isinstance(key, str) or not key.replace("_", "").isalnum() or not key[0].isalpha():
            raise ValueError(f"invalid environment variable name: {key!r}")
        if not isinstance(value, str) or len(value) > 4096:
            raise ValueError(f"environment value for {key} must be a string up to 4096 chars")
    return task, cwd


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--task-file", required=True)
    parser.add_argument("--output", default="results/execution.json")
    args = parser.parse_args()

    started_at = utc_now()
    start = time.monotonic()
    result: dict[str, Any] = {
        "schema_version": 1,
        "status": "error",
        "task_file": args.task_file,
        "started_at": started_at,
        "completed_at": None,
        "duration_seconds": None,
        "command": None,
        "cwd": None,
        "exit_code": None,
        "timed_out": False,
        "stdout": "",
        "stderr": "",
        "error": None,
    }
    try:
        task, cwd = load_task(args.task_file)
        result["task_name"] = str(task.get("name", args.task_file))[:200]
        result["command"] = task["command"]
        result["cwd"] = str(cwd.relative_to(ROOT))
        env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("GITHUB_", "ACTIONS_", "INPUT_", "RUNNER_"))}
        env.update(task.get("env", {}))
        completed = subprocess.run(
            task["command"],
            cwd=cwd,
            env=env,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=task.get("timeout_seconds", 300),
            shell=False,
            check=False,
        )
        result["stdout"] = completed.stdout[-MAX_OUTPUT_CHARS:]
        result["stderr"] = completed.stderr[-MAX_OUTPUT_CHARS:]
        result["exit_code"] = completed.returncode
        result["status"] = "success" if completed.returncode == 0 else "failed"
    except subprocess.TimeoutExpired as exc:
        result["status"] = "timed_out"
        result["timed_out"] = True
        result["stdout"] = (exc.stdout or "")[-MAX_OUTPUT_CHARS:] if isinstance(exc.stdout, str) else ""
        result["stderr"] = (exc.stderr or "")[-MAX_OUTPUT_CHARS:] if isinstance(exc.stderr, str) else ""
        result["error"] = "Task exceeded its configured timeout"
    except Exception as exc:  # Evidence must still be emitted for invalid manifests.
        result["status"] = "error"
        result["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        result["completed_at"] = utc_now()
        result["duration_seconds"] = round(time.monotonic() - start, 3)
        output = (ROOT / args.output).resolve()
        if not output.is_relative_to(ROOT):
            print("Output path must remain inside workspace", file=sys.stderr)
            return 2
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: result[k] for k in ("status", "exit_code", "duration_seconds", "error")}, indent=2))
    return 0 if result["status"] == "success" else 1


if __name__ == "__main__":
    raise SystemExit(main())
