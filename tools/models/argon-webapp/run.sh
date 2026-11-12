#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="https://github.com/veerack/argon-webapp.git"
UPSTREAM_REF="${ARGON_WEBAPP_REF:-main}"
RUNTIME_ROOT="${ARGON_WEBAPP_RUNTIME_DIR:-$HOME/.agent-workspace/argon-webapp}"
TARGET_WORKSPACE="${1:-}"

if [[ -z "$TARGET_WORKSPACE" ]]; then
  echo "Usage: $0 /absolute/path/to/target/repository" >&2
  exit 2
fi

TARGET_WORKSPACE="$(cd "$TARGET_WORKSPACE" && pwd)"

if [[ ! -d "$TARGET_WORKSPACE" ]]; then
  echo "Target workspace does not exist: $TARGET_WORKSPACE" >&2
  exit 2
fi

mkdir -p "$(dirname "$RUNTIME_ROOT")"

if [[ ! -d "$RUNTIME_ROOT/.git" ]]; then
  rm -rf "$RUNTIME_ROOT"
  git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$RUNTIME_ROOT"
fi

cd "$RUNTIME_ROOT"

if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
fi

"$RUNTIME_ROOT/.venv/bin/python" -m pip install --disable-pip-version-check -r requirements.txt

export STUDIO_WORKSPACE="$TARGET_WORKSPACE"

echo "Argon/Carbon transient tool"
echo "Workspace: $TARGET_WORKSPACE"
echo "Runtime:   $RUNTIME_ROOT"
echo "URL:       http://localhost:4321"
echo "Stop with Ctrl-C. Remove the transient runtime with tools/models/argon-webapp/cleanup.sh."

exec "$RUNTIME_ROOT/.venv/bin/python" server.py
