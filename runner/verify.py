#!/usr/bin/env python3
"""Validate the execution evidence contract; does not rerun task code."""
import argparse
import json
from pathlib import Path

REQUIRED = {
    "schema_version", "status", "task_file", "started_at", "completed_at",
    "duration_seconds", "command", "cwd", "exit_code", "timed_out",
    "stdout", "stderr", "error",
}
VALID_STATUSES = {"success", "failed", "timed_out", "error"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result", required=True)
    args = parser.parse_args()
    data = json.loads(Path(args.result).read_text(encoding="utf-8"))
    missing = REQUIRED - data.keys()
    if missing:
        raise SystemExit(f"Missing result fields: {sorted(missing)}")
    if data["schema_version"] != 1 or data["status"] not in VALID_STATUSES:
        raise SystemExit("Unsupported result schema or status")
    if not isinstance(data["duration_seconds"], (int, float)):
        raise SystemExit("duration_seconds must be numeric")
    if not isinstance(data["stdout"], str) or not isinstance(data["stderr"], str):
        raise SystemExit("stdout and stderr must be strings")
    print(f"VALID RESULT: {data['status']} (exit_code={data['exit_code']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
