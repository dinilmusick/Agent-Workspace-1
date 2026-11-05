#!/usr/bin/env python3
"""Set an existing GitHub repository's public/private visibility."""

from __future__ import annotations

import argparse
import json
import os
import sys
from urllib import error, request


API_ROOT = "https://api.github.com/repos"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Set an existing GitHub repository's visibility."
    )
    parser.add_argument(
        "--repository",
        required=True,
        help="Repository in owner/name form.",
    )
    parser.add_argument(
        "--visibility",
        required=True,
        choices=("private", "public"),
        help="Target visibility.",
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def build_payload(visibility: str) -> dict[str, object]:
    return {"private": visibility == "private"}


def api_request(
    repository: str,
    token: str,
    *,
    method: str,
    payload: dict[str, object] | None = None,
) -> dict:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = request.Request(
        f"{API_ROOT}/{repository}",
        data=body,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "agent-workspace-github-tool",
        },
    )
    try:
        with request.urlopen(req, timeout=30) as response:
            if response.status < 200 or response.status >= 300:
                raise RuntimeError(f"unexpected HTTP status {response.status}")
            return json.load(response)
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        try:
            message = json.loads(detail).get("message", "GitHub API error")
        except json.JSONDecodeError:
            message = "GitHub API error"
        raise RuntimeError(f"GitHub API rejected visibility change: {message}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"GitHub API request failed: {exc.reason}") from exc


def main() -> int:
    args = parse_args()

    if "/" not in args.repository or args.repository.count("/") != 1:
        print("--repository must be owner/name", file=sys.stderr)
        return 2

    payload = build_payload(args.visibility)
    if args.dry_run:
        print(json.dumps({
            "operation": f"PATCH /repos/{args.repository}",
            "payload": payload,
            "verification": f"GET /repos/{args.repository}",
        }, indent=2))
        return 0

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        print(
            "Missing GITHUB_TOKEN or GH_TOKEN; refusing to mutate GitHub.",
            file=sys.stderr,
        )
        return 2

    result = api_request(
        args.repository,
        token,
        method="PATCH",
        payload=payload,
    )
    verified = api_request(args.repository, token, method="GET")

    expected_private = args.visibility == "private"
    if verified.get("private") is not expected_private:
        print("GitHub visibility verification failed.", file=sys.stderr)
        return 1

    print(json.dumps({
        "repository": result.get("full_name", args.repository),
        "visibility": "private" if verified.get("private") else "public",
        "url": verified.get("html_url"),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
