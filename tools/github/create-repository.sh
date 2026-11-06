#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
NAME="${1:?repository name is required}"
VISIBILITY="${2:-private}"
DESCRIPTION="${3:-}"

case "$VISIBILITY" in
  private) PRIVATE=true ;;
  public) PRIVATE=false ;;
  *) echo "visibility must be private or public" >&2; exit 2 ;;
esac

python3 - "$NAME" "$PRIVATE" "$DESCRIPTION" <<'PY'
import json, os, sys, urllib.request, urllib.error
name, private, description = sys.argv[1], sys.argv[2] == "true", sys.argv[3]
if not all(c.isalnum() or c in "._-" for c in name) or len(name) > 100:
    raise SystemExit("invalid repository name")

token = os.environ["GITHUB_TOKEN"]
headers = {
    "Accept": "application/vnd.github+json",
    "Authorization": f"Bearer {token}",
    "X-GitHub-Api-Version": "2026-03-10",
}

# Idempotent bootstrap: if the target repository was created by a prior attempt,
# reuse it rather than failing with HTTP 422.
check = urllib.request.Request(f"https://api.github.com/repos/dinilmusick/{name}", headers=headers)
try:
    with urllib.request.urlopen(check) as r:
        data = json.load(r)
    print(data["full_name"])
    print(data["html_url"])
    sys.exit(0)
except urllib.error.HTTPError as e:
    if e.code != 404:
        print(e.read().decode(), file=sys.stderr)
        raise

body = json.dumps({
    "name": name,
    "private": private,
    "description": description,
    "auto_init": True,
}).encode()

req = urllib.request.Request(
    "https://api.github.com/user/repos",
    data=body,
    method="POST",
    headers={**headers, "Content-Type": "application/json"},
)
try:
    with urllib.request.urlopen(req) as r:
        data = json.load(r)
except urllib.error.HTTPError as e:
    print(e.read().decode(), file=sys.stderr)
    raise

print(data["full_name"])
print(data["html_url"])
PY
