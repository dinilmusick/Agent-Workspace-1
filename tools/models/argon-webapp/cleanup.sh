#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${ARGON_WEBAPP_RUNTIME_DIR:-$HOME/.agent-workspace/argon-webapp}"

if [[ -z "$RUNTIME_ROOT" || "$RUNTIME_ROOT" == "/" ]]; then
  echo "Refusing unsafe cleanup path: $RUNTIME_ROOT" >&2
  exit 1
fi

if [[ -e "$RUNTIME_ROOT" ]]; then
  rm -rf "$RUNTIME_ROOT"
  echo "Removed transient Argon runtime: $RUNTIME_ROOT"
else
  echo "No transient Argon runtime found: $RUNTIME_ROOT"
fi
