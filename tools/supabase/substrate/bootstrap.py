#!/usr/bin/env python3
"""Provision and recover the Agent Workspace Supabase substrate."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SUPABASE_DIR = ROOT / "supabase"
MIGRATIONS_DIR = SUPABASE_DIR / "migrations"
SEED_FILE = SUPABASE_DIR / "seed.sql"


class SubstrateError(RuntimeError):
    pass


def cli() -> str:
    value = shutil.which("supabase")
    if not value:
        raise SubstrateError(
            "Supabase CLI is required; install it before running substrate commands"
        )
    return value


def project_ref(value: str | None) -> str:
    ref = (value or os.getenv("SUPABASE_PROJECT_ID", "")).strip()
    if not ref:
        raise SubstrateError("SUPABASE_PROJECT_ID or --project-ref is required")
    if not ref.replace("-", "").isalnum():
        raise SubstrateError("Invalid Supabase project ref")
    return ref


def require_remote_credentials() -> None:
    missing = [
        name
        for name in ("SUPABASE_ACCESS_TOKEN", "SUPABASE_DB_PASSWORD")
        if not os.getenv(name)
    ]
    if missing:
        raise SubstrateError(
            "Missing runtime secret(s): " + ", ".join(missing)
        )


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if proc.returncode:
        detail = (proc.stderr or proc.stdout).strip()
        raise SubstrateError(
            f"Command failed ({proc.returncode}): {detail[:2000]}"
        )
    return proc


def migration_files() -> list[Path]:
    if not MIGRATIONS_DIR.is_dir():
        raise SubstrateError(f"Missing migrations directory: {MIGRATIONS_DIR}")
    return sorted(MIGRATIONS_DIR.glob("*.sql"))


def doctor() -> dict[str, object]:
    result: dict[str, object] = {
        "supabase_cli": shutil.which("supabase") is not None,
        "config": (SUPABASE_DIR / "config.toml").is_file(),
        "seed": SEED_FILE.is_file(),
        "migration_count": len(migration_files()),
        "access_token_set": bool(os.getenv("SUPABASE_ACCESS_TOKEN")),
        "db_password_set": bool(os.getenv("SUPABASE_DB_PASSWORD")),
        "project_ref_set": bool(os.getenv("SUPABASE_PROJECT_ID")),
    }
    result["ready_for_hosted_push"] = all(
        (
            result["supabase_cli"],
            result["config"],
            result["seed"],
            result["migration_count"] > 0,
            result["access_token_set"],
            result["db_password_set"],
            result["project_ref_set"],
        )
    )
    return result


def plan() -> dict[str, object]:
    files = migration_files()
    return {
        "source": str(SUPABASE_DIR.relative_to(ROOT)),
        "migration_count": len(files),
        "first_migration": files[0].name if files else None,
        "last_migration": files[-1].name if files else None,
        "seed": SEED_FILE.relative_to(ROOT).as_posix(),
        "seed_bytes": SEED_FILE.stat().st_size if SEED_FILE.exists() else 0,
    }


def push(ref: str | None) -> dict[str, object]:
    require_remote_credentials()
    target = project_ref(ref)
    proc = run_command(
        [cli(), "db", "push", f"--remote={target}", "--include-seed", "--yes"]
    )
    return {
        "project_ref": target,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "migration_count": len(migration_files()),
    }


def status(ref: str | None) -> dict[str, object]:
    require_remote_credentials()
    target = project_ref(ref)
    proc = run_command([cli(), "migration", "list", f"--remote={target}"])
    return {"project_ref": target, "stdout": proc.stdout, "stderr": proc.stderr}


def test() -> dict[str, object]:
    proc = run_command([cli(), "test", "db", "--local"])
    return {"stdout": proc.stdout, "stderr": proc.stderr}


def dump(ref: str | None, output: str) -> dict[str, object]:
    require_remote_credentials()
    target = project_ref(ref)
    out = Path(output).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    schema = out / "schema.sql"
    data = out / "data.sql"

    run_command(
        [cli(), "db", "dump", f"--remote={target}", "--schema", "public", "--file", str(schema)]
    )
    run_command(
        [cli(), "db", "dump", f"--remote={target}", "--schema", "public", "--data-only", "--file", str(data)]
    )
    return {"project_ref": target, "schema": str(schema), "data": str(data)}


def parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Agent Workspace Supabase substrate tool")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("doctor")
    sub.add_parser("plan")
    for name in ("push", "status"):
        command = sub.add_parser(name)
        command.add_argument("--project-ref")
    sub.add_parser("test")
    command = sub.add_parser("dump")
    command.add_argument("--project-ref")
    command.add_argument("--output", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    try:
        args = parser().parse_args(argv)
        if args.command == "doctor":
            result = doctor()
        elif args.command == "plan":
            result = plan()
        elif args.command == "push":
            result = push(args.project_ref)
        elif args.command == "status":
            result = status(args.project_ref)
        elif args.command == "test":
            result = test()
        else:
            result = dump(args.project_ref, args.output)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    except SubstrateError as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
