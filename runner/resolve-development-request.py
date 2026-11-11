#!/usr/bin/env python3
"""Resolve and validate a GitHub Development Workspace request."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any

AUTHORIZED_ASSOCIATIONS = {"OWNER", "MEMBER", "COLLABORATOR"}
REPOSITORY_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")


def _valid_git_ref(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 200 or value.startswith("-"):
        raise ValueError(f"{label} must be a non-empty Git ref of at most 200 characters.")
    result = subprocess.run(
        ["git", "check-ref-format", "--allow-onelevel", value],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise ValueError(f"{label} is not a valid Git ref: {value!r}")
    return value


def _single_line(value: Any, label: str, *, required: bool = False) -> str:
    if not isinstance(value, str) or "\n" in value or "\r" in value:
        raise ValueError(f"{label} must be a single-line string.")
    if required and not value.strip():
        raise ValueError(f"{label} is required.")
    return value


def validate_request(request: dict[str, Any]) -> dict[str, Any]:
    repository = request.get("repository")
    if not isinstance(repository, str) or not REPOSITORY_RE.fullmatch(repository):
        raise ValueError("repository must use owner/name format.")

    ref = _valid_git_ref(request.get("ref", "main"), "ref")
    source_repository = request.get("source_repository", "")
    if not isinstance(source_repository, str) or (source_repository and not REPOSITORY_RE.fullmatch(source_repository)):
        raise ValueError("source_repository must be empty or use owner/name format.")
    source_ref = _valid_git_ref(request.get("source_ref", "main"), "source_ref") if source_repository else ""
    commands = request.get("commands", [])
    if isinstance(commands, list) and all(isinstance(item, str) for item in commands):
        command_text = "\n".join(commands).strip()
    elif isinstance(commands, str):
        command_text = commands.strip()
    else:
        raise ValueError("commands must be a string or an array of strings.")

    if not command_text or len(command_text) > 20_000:
        raise ValueError("commands must contain 1–20,000 characters.")
    if len(command_text.splitlines()) > 100:
        raise ValueError("At most 100 command lines are allowed.")

    push = request.get("push", False)
    create_pr = request.get("create_pr", False)
    if not isinstance(push, bool) or not isinstance(create_pr, bool):
        raise ValueError("push and create_pr must be booleans.")

    branch = request.get("branch", "")
    if push:
        branch = _valid_git_ref(branch, "branch")
    elif branch and not isinstance(branch, str):
        raise ValueError("branch must be a string.")
    if create_pr and not push:
        raise ValueError("create_pr requires push=true.")

    pr_body = request.get("pr_body", "")
    if not isinstance(pr_body, str) or len(pr_body) > 20_000:
        raise ValueError("pr_body must be a string of at most 20,000 characters.")

    return {
        "repository": repository,
        "ref": ref,
        "source_repository": source_repository,
        "source_ref": source_ref,
        "commands": command_text,
        "push": push,
        "branch": branch,
        "create_pr": create_pr,
        "commit_message": _single_line(
            request.get("commit_message", "chore: agent workspace changes"), "commit_message", required=push
        ),
        "pr_title": _single_line(request.get("pr_title", ""), "pr_title"),
        "pr_body": pr_body,
    }


def resolve_request(event_name: str, event: dict[str, Any], env: dict[str, str]) -> dict[str, Any]:
    if event_name == "issues":
        issue = event.get("issue") or {}
        if not str(issue.get("title", "")).startswith("[github-dev]"):
            raise ValueError("Issue title must start with [github-dev].")
        if issue.get("author_association") not in AUTHORIZED_ASSOCIATIONS:
            raise ValueError("Issue author must be a repository owner, member, or collaborator.")
        try:
            raw = json.loads(issue.get("body") or "")
        except json.JSONDecodeError as exc:
            raise ValueError(f"Issue body must contain a JSON request: {exc}") from exc
        if not isinstance(raw, dict):
            raise ValueError("Issue body must be a JSON object.")
        return validate_request(raw)

    if event_name != "workflow_dispatch":
        raise ValueError(f"Unsupported event: {event_name}")
    return validate_request({
        "repository": env.get("INPUT_REPOSITORY", ""),
        "ref": env.get("INPUT_REF", "main"),
        "source_repository": env.get("INPUT_SOURCE_REPOSITORY", ""),
        "source_ref": env.get("INPUT_SOURCE_REF", "main"),
        "commands": env.get("INPUT_COMMANDS", ""),
        "push": env.get("INPUT_PUSH", "false").lower() == "true",
        "branch": env.get("INPUT_BRANCH", ""),
        "create_pr": env.get("INPUT_CREATE_PR", "false").lower() == "true",
        "commit_message": env.get("INPUT_COMMIT_MESSAGE", "chore: agent workspace changes"),
        "pr_title": env.get("INPUT_PR_TITLE", ""),
        "pr_body": env.get("INPUT_PR_BODY", ""),
    })


def write_outputs(request: dict[str, Any], runner_temp: str, output_path: str) -> None:
    command_file = Path(runner_temp) / "agent-development-commands.sh"
    command_file.write_text(
        "#!/usr/bin/env bash\nset -euo pipefail\n" + request["commands"] + "\n",
        encoding="utf-8",
    )
    command_file.chmod(0o700)
    values = {key: value for key, value in request.items() if key != "commands"}
    values["command_file"] = str(command_file)
    with open(output_path, "a", encoding="utf-8") as output:
        for key, value in values.items():
            value = str(value)
            if "\n" not in value and "\r" not in value:
                output.write(f"{key}={value}\n")
                continue
            delimiter = f"VALUE_{uuid.uuid4().hex}"
            while delimiter in value:
                delimiter = f"VALUE_{uuid.uuid4().hex}"
            output.write(f"{key}<<{delimiter}\n{value}\n{delimiter}\n")


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        raise SystemExit("GITHUB_EVENT_PATH is required.")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    request = resolve_request(os.environ.get("GITHUB_EVENT_NAME", ""), event, os.environ)
    write_outputs(request, os.environ["RUNNER_TEMP"], os.environ["GITHUB_OUTPUT"])
    print(json.dumps({key: value for key, value in request.items() if key != "commands"}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"Invalid development request: {error}", file=sys.stderr)
        raise SystemExit(2)
