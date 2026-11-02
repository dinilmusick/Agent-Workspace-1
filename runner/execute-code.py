#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

MAX_OUTPUT = 30000
ROOT = Path(os.environ.get("GITHUB_WORKSPACE", Path(__file__).resolve().parents[1])).resolve()


def parse_arguments(value):
    parsed = json.loads(value or "[]")
    if not isinstance(parsed, list) or not all(isinstance(item, str) for item in parsed):
        raise ValueError("arguments must be a JSON array of strings")
    return parsed


def safe_source_path(value):
    source = (ROOT / value).resolve()
    if not source.is_relative_to(ROOT):
        raise ValueError("source_file must resolve inside the checked-out workspace")
    if not source.is_file():
        raise FileNotFoundError(f"source file does not exist: {value}")
    return source


def clean_environment(temp_home):
    allowed = ("PATH", "LANG", "LC_ALL", "JAVA_HOME", "DOTNET_ROOT", "GOROOT",
               "GOPATH", "RUSTUP_HOME", "CARGO_HOME")
    environment = {key: os.environ[key] for key in allowed if key in os.environ}
    environment.update({"HOME": str(temp_home), "CI": "true", "NO_COLOR": "1"})
    return environment


def run_command(command, timeout, environment, cwd):
    return subprocess.run(command, cwd=cwd, env=environment, timeout=timeout,
                          capture_output=True, text=True, check=False)


def execute(runtime, source, arguments, timeout, temp_dir, environment):
    if runtime == "python":
        return run_command([sys.executable, str(source), *arguments], timeout, environment, ROOT)
    if runtime == "node":
        return run_command(["node", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "typescript":
        return run_command(["npx", "--yes", "tsx", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "bash":
        return run_command(["bash", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "powershell":
        return run_command(["pwsh", "-NoProfile", "-File", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "go":
        return run_command(["go", "run", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "ruby":
        return run_command(["ruby", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "php":
        return run_command(["php", str(source), *arguments], timeout, environment, ROOT)
    if runtime == "rust":
        binary = Path(temp_dir) / "agent-program"
        compiled = run_command(["rustc", str(source), "-o", str(binary)], timeout, environment, ROOT)
        if compiled.returncode:
            return compiled
        return run_command([str(binary), *arguments], timeout, environment, ROOT)
    if runtime == "java":
        compiled = run_command(["javac", "-d", temp_dir, str(source)], timeout, environment, ROOT)
        if compiled.returncode:
            return compiled
        return run_command(["java", "-cp", temp_dir, source.stem, *arguments], timeout, environment, ROOT)
    if runtime == "csharp":
        project = Path(temp_dir) / "agent-program"
        created = run_command(["dotnet", "new", "console", "--output", str(project), "--no-restore"],
                              timeout, environment, ROOT)
        if created.returncode:
            return created
        shutil.copyfile(source, project / "Program.cs")
        return run_command(["dotnet", "run", "--project", str(project), "--", *arguments],
                           timeout, environment, project)
    raise ValueError(f"unsupported runtime: {runtime}")


def main():
    parser = argparse.ArgumentParser(description="Execute one source file in an ephemeral GitHub-hosted runner.")
    parser.add_argument("--runtime", required=True)
    parser.add_argument("--source-file", required=True)
    parser.add_argument("--arguments", default="[]")
    parser.add_argument("--timeout-seconds", type=int, default=300)
    parser.add_argument("--output", default="results/compute-result.json")
    args = parser.parse_args()
    result = {"runtime": args.runtime, "source_file": args.source_file, "exit_code": None,
              "stdout": "", "stderr": "", "timed_out": False, "error": None}
    try:
        if not 1 <= args.timeout_seconds <= 1200:
            raise ValueError("timeout_seconds must be between 1 and 1200")
        arguments = parse_arguments(args.arguments)
        source = safe_source_path(args.source_file)
        with tempfile.TemporaryDirectory(prefix="agent-compute-") as temp_dir:
            temp_home = Path(temp_dir) / "home"
            temp_home.mkdir()
            environment = clean_environment(temp_home)
            try:
                completed = execute(args.runtime, source, arguments, args.timeout_seconds,
                                    temp_dir, environment)
                result.update({"exit_code": completed.returncode,
                               "stdout": completed.stdout[-MAX_OUTPUT:],
                               "stderr": completed.stderr[-MAX_OUTPUT:]})
            except subprocess.TimeoutExpired as error:
                result.update({"timed_out": True,
                               "stdout": (error.stdout or "")[-MAX_OUTPUT:] if isinstance(error.stdout, str) else "",
                               "stderr": (error.stderr or "")[-MAX_OUTPUT:] if isinstance(error.stderr, str) else "",
                               "error": f"Execution exceeded {args.timeout_seconds} seconds"})
    except Exception as error:
        result["error"] = str(error)
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["exit_code"] == 0 and not result["error"] and not result["timed_out"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
