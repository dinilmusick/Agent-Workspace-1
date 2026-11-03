#!/usr/bin/env python3
"""Create a GitHub repository for the authenticated user.

Authentication is read only from GITHUB_TOKEN or GH_TOKEN.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from urllib import error, request

API = "https://api.github.com/user/repos"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a GitHub repository.")
    parser.add_argument("--name", required=True, help="New repository name.")
    parser.add_argument("--description", default="", help="Repository description.")
    parser.add_argument("--visibility", choices=("private", "public"), default="private")
    parser.add_argument("--private", action="store_true", help="Create a private repository.")
    parser.add_argument("--public", action="store_true", help="Create a public repository.")
    parser.add_argument("--initialize", action="store_true", help="Initialize with an empty README.")
    parser.add_argument("--gitignore-template", default=None)
    parser.add_argument("--license-template", default=None)
    parser.add_argument("--homepage", default=None)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def build_payload(args: argparse.Namespace) -> dict:
    if args.private and args.public:
        raise SystemExit("--private and --public are mutually exclusive")

    visibility = "private" if args.private else "public" if args.public else args.visibility
    payload = {
        "name": args.name,
        "description": args.description,
        "private": visibility == "private",
        "auto_init": args.initialize,
    }

    if args.gitignore_template:
        payload["gitignore_template"] = args.gitignore_template
    if args.license_template:
        payload["license_template"] = args.license_template
    if args.homepage:
        payload["homepage":] = args.homepage
    return payload


def create_repository(payload: dict, token: str) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = request.Request(
        API,
        data=body,
        method="POST",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "agent-workspace-repository-tool",
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
        raise RuntimeError(f"GitHub API rejected repository creation: {message}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"GitHub API request failed: {exc.reason}") from exc


def main() -> int:
    args = parse_args()
    payload = build_payload(args)

    if args.dry_run:
        print(json.dumps({"operation": "POST /user/repos", "payload": payload}, indent=2))
        return 0

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        print("Missing GITHUB_TOKEN or GH_TOKEN; refusing to mutate GitHub.", file=sys.stderr)
        return 2

    result = create_repository(payload, token)
    print(json.dumps({
        "repository": result.get("full_name"),
        "url": result.get("html_url"),
        "default_branch": result.get("default_branch"),
        "visibility": "private" if result.get("private") else "public",
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
