#!/usr/bin/env python3
"""Local-only Cloudflare, Vercel and Supabase development adapters."""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SUPABASE_EXCLUDES = "gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor,analytics"
SECRET_NAMES = ("TOKEN", "SECRET", "PASSWORD", "API_KEY")

class AdapterError(RuntimeError):
    pass

def redact(value, env):
    for key, secret in env.items():
        if secret and any(part in key.upper() for part in SECRET_NAMES):
            value = value.replace(secret, "[REDACTED]")
    return value

def run(command, cwd, log_path, env=None):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, cwd=cwd, env=env or os.environ.copy(),
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = redact(result.stdout, env or os.environ)
    log_path.write_text(output, encoding="utf-8")
    if result.returncode:
        raise AdapterError(f"{command[0]} exited {result.returncode}; see {log_path}")
    return output

def package_command(project, executable):
    if (project / "pnpm-lock.yaml").is_file():
        return ["corepack", "pnpm", "exec", executable]
    if (project / "yarn.lock").is_file():
        return ["corepack", "yarn", executable]
    return ["npx", "--no-install", executable]

def run_cloudflare(project, output):
    config = next((project / name for name in ("wrangler.jsonc", "wrangler.json", "wrangler.toml") if (project / name).is_file()), None)
    if config is None:
        return {"status": "skipped", "reason": "No Wrangler configuration found"}
    package_file = project / "package.json"
    if not package_file.is_file():
        raise AdapterError("Cloudflare Worker project requires package.json")
    package = json.loads(package_file.read_text(encoding="utf-8"))
    deps = {**package.get("dependencies", {}), **package.get("devDependencies", {})}
    if "@cloudflare/vitest-plugin" not in deps:
        raise AdapterError("Use @cloudflare/vitest-plugin for local Worker-runtime tests; legacy vitest-pool-workers is not accepted")
    config_file = next((project / name for name in ("vitest.config.ts", "vitest.config.mts", "vitest.config.js", "vitest.config.mjs") if (project / name).is_file()), None)
    if config_file is None or "cloudflareTest" not in config_file.read_text(encoding="utf-8"):
        raise AdapterError("Cloudflare project is missing vitest.config with cloudflareTest()")
    command = package_command(project, "vitest") + ["run"]
    run(command, project, output / "cloudflare-vitest.log")
    return {"status": "passed", "runtime": "Cloudflare Workers via @cloudflare/vitest-plugin/Miniflare", "config": str(config.relative_to(project))}

def validate_preview_url(value):
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.hostname or not parsed.hostname.endswith(".vercel.app"):
        raise AdapterError("VERCEL_PREVIEW_URL must be an HTTPS *.vercel.app deployment URL")
    if parsed.username or parsed.password:
        raise AdapterError("VERCEL_PREVIEW_URL cannot embed credentials")
    return value.rstrip("/")

def http_preview(url, output):
    request = Request(url, headers={"user-agent": "agent-workspace-platform-adapter/1"})
    try:
        response = urlopen(request, timeout=15)
    except HTTPError as error:
        response = error
    except URLError as error:
        raise AdapterError(f"Vercel preview request failed: {error.reason}") from error
    report = {"url": url, "status": response.status,
        "headers": {key: value for key, value in response.headers.items() if key.lower() not in ("set-cookie", "authorization")}}
    response.close()
    (output / "vercel-preview-http.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not 200 <= response.status < 400:
        raise AdapterError(f"Vercel preview returned HTTP {response.status}")
    return report

def run_vercel(project, output):
    config = project / "vercel.json"
    link = project / ".vercel" / "project.json"
    if not config.is_file() and not link.is_file():
        return {"status": "skipped", "reason": "No vercel.json or .vercel/project.json found"}
    if config.is_file():
        json.loads(config.read_text(encoding="utf-8"))
    token = os.environ.get("VERCEL_TOKEN")
    results = {"status": "passed", "localBuild": "skipped", "preview": "skipped"}
    if token and link.is_file():
        env = os.environ.copy()
        try:
            run(["vercel", "pull", "--yes", "--environment=preview"], project, output / "vercel-pull.log", env)
            run(["vercel", "build"], project, output / "vercel-build.log", env)
            results["localBuild"] = "passed"
        finally:
            (project / ".vercel" / ".env.preview.local").unlink(missing_ok=True)
    preview = os.environ.get("VERCEL_PREVIEW_URL")
    if preview:
        preview = validate_preview_url(preview)
        if token:
            inspect = run(["vercel", "inspect", preview], project, output / "vercel-inspect.log")
            target = re.search(r"\btarget\s*[:=]\s*(preview|production|development)\b", inspect, re.I)
            declared = os.environ.get("VERCEL_DEPLOYMENT_TARGET", "").lower()
            if target and target.group(1).lower() != "preview":
                raise AdapterError("Refusing Vercel diagnostics for a non-preview deployment")
            if not target and declared != "preview":
                raise AdapterError("Could not prove deployment is Preview; set VERCEL_DEPLOYMENT_TARGET=preview after checking the deployment")
            run(["vercel", "inspect", preview, "--logs"], project, output / "vercel-build-logs.log")
            run(["vercel", "curl", "/", "--deployment", preview], project, output / "vercel-preview-curl.log")
            run(["vercel", "logs", "--deployment", preview, "--level", "error", "--json"], project, output / "vercel-runtime-errors.jsonl")
            results["preview"] = "inspected"
        else:
            http_preview(preview, output)
            results["preview"] = "public-http-smoke-only"
    results["localBuild"] = results["localBuild"] if results["localBuild"] != "skipped" else "skipped (requires VERCEL_TOKEN and linked project)"
    if results["preview"] == "skipped":
        results["preview"] = "skipped (set VERCEL_PREVIEW_URL for preview validation)"
    return results

def run_supabase(project, output):
    config = project / "supabase" / "config.toml"
    if not config.is_file():
        return {"status": "skipped", "reason": "No supabase/config.toml found"}
    if not shutil.which("supabase"):
        raise AdapterError("Supabase CLI is required for local migrations and pgTAP tests")
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("SUPABASE_") and key != "SUPABASE_TELEMETRY_DISABLED":
            env.pop(key, None)
    env["SUPABASE_TELEMETRY_DISABLED"] = "1"
    version = run(["supabase", "--version"], project, output / "supabase-version.log", env)
    if not re.search(r"\b3\.\d+\.\d+\b", version):
        raise AdapterError("Supabase CLI v3 is required for the local-only adapter")
    tests = project / "supabase" / "tests"
    test_files = list(tests.glob("*.sql")) + list(tests.glob("*.pg")) if tests.is_dir() else []
    started = False
    try:
        run(["supabase", "start", "--exclude", SUPABASE_EXCLUDES], project, output / "supabase-start.log", env)
        started = True
        run(["supabase", "db", "reset"], project, output / "supabase-migrations.log", env)
        if test_files:
            run(["supabase", "test", "db"], project, output / "supabase-pgtap.log", env)
        return {"status": "passed", "target": "local-postgres-only", "migrations": "applied",
            "databaseTests": "passed" if test_files else "skipped (no supabase/tests/*.sql or *.pg)"}
    finally:
        if started:
            run(["supabase", "stop"], project, output / "supabase-stop.log", env)

def run_provider(provider, project, output):
    output.mkdir(parents=True, exist_ok=True)
    if provider == "cloudflare":
        return run_cloudflare(project, output)
    if provider == "vercel":
        return run_vercel(project, output)
    if provider == "supabase":
        return run_supabase(project, output)
    raise AdapterError(f"Unknown platform adapter: {provider}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("provider", choices=["all", "cloudflare", "vercel", "supabase"])
    parser.add_argument("--project-path", type=Path, default=Path("workspaces/target"))
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts/platforms"))
    args = parser.parse_args()
    project = args.project_path.resolve()
    output = args.output_dir.resolve()
    if not project.is_dir():
        raise SystemExit(f"Project directory does not exist: {project}")
    providers = ["cloudflare", "vercel", "supabase"] if args.provider == "all" else [args.provider]
    summary = {"project": str(project), "providers": {}, "status": "passed"}
    for provider in providers:
        try:
            summary["providers"][provider] = run_provider(provider, project, output / provider)
        except Exception as error:
            summary["providers"][provider] = {"status": "failed", "error": str(error)}
            summary["status"] = "failed"
    output.mkdir(parents=True, exist_ok=True)
    (output / "platform-adapters.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 1 if summary["status"] == "failed" else 0

if __name__ == "__main__":
    raise SystemExit(main())
