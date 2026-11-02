#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

RUNTIMES = {
    "python", "node", "typescript", "bash", "go", "rust", "java",
    "c", "cpp", "csharp", "ruby", "php", "perl", "r", "powershell",
}
ALLOWED_AUTHORS = {"OWNER", "MEMBER", "COLLABORATOR"}


def validate(request):
    ref = str(request.get("ref", "main")).strip()
    runtime = str(request.get("runtime", "")).strip().lower()
    source_file = str(request.get("source_file", "")).strip()
    arguments = request.get("arguments", [])
    timeout = int(request.get("timeout_seconds", 300))
    if not ref or "\n" in ref or "\r" in ref:
        raise ValueError("ref must be a single non-empty branch, tag or commit")
    if runtime not in RUNTIMES:
        raise ValueError(f"unsupported runtime: {runtime}")
    if not source_file or "\n" in source_file or "\r" in source_file:
        raise ValueError("source_file must be a repository-relative path")
    if Path(source_file).is_absolute() or ".." in Path(source_file).parts:
        raise ValueError("source_file cannot escape the workspace")
    if not isinstance(arguments, list) or not all(isinstance(x, str) for x in arguments):
        raise ValueError("arguments must be a JSON array of strings")
    if not 1 <= timeout <= 1200:
        raise ValueError("timeout_seconds must be between 1 and 1200")
    return {
        "ref": ref,
        "runtime": runtime,
        "source_file": source_file,
        "arguments": json.dumps(arguments, separators=(",", ":")),
        "timeout_seconds": str(timeout),
    }


def main():
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    if event_name == "workflow_dispatch":
        request = {
            "ref": os.environ.get("INPUT_REF", "main"),
            "runtime": os.environ.get("INPUT_RUNTIME", "python"),
            "source_file": os.environ.get("INPUT_SOURCE_FILE", ""),
            "arguments": json.loads(os.environ.get("INPUT_ARGUMENTS", "[]")),
            "timeout_seconds": os.environ.get("INPUT_TIMEOUT_SECONDS", "300"),
        }
    elif event_name == "issues":
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
        issue = event.get("issue", {})
        if not str(issue.get("title", "")).startswith("[agent-compute]"):
            raise ValueError("issue title must start with [agent-compute]")
        if issue.get("author_association") not in ALLOWED_AUTHORS:
            raise PermissionError("compute requests are limited to repository owners, members and collaborators")
        request = json.loads(issue.get("body") or "")
    else:
        raise ValueError(f"unsupported trigger: {event_name}")

    values = validate(request)
    output_path = Path(os.environ.get("GITHUB_OUTPUT", ""))
    if not str(output_path):
        raise RuntimeError("GITHUB_OUTPUT is not available")
    with output_path.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")
    print(json.dumps({"accepted": True, "runtime": values["runtime"],
                      "ref": values["ref"], "source_file": values["source_file"]}))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
