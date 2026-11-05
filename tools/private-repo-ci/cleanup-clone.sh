#!/usr/bin/env bash
set -euo pipefail

ROOT="${CLONE_ROOT:-${GITHUB_WORKSPACE}/clones}"
TARGET_REPOSITORY="${TARGET_REPOSITORY:?TARGET_REPOSITORY is required}"

repo="${TARGET_REPOSITORY#https://github.com/}"
repo="${repo#git@github.com:}"
repo="${repo%.git}"
owner="${repo%%/*}"
name="${repo#*/}"
DEST="$ROOT/${owner}__${name}"

if [[ -d "$DEST" ]]; then
  rm -rf "$DEST"
fi

# The dedicated clone directory must be empty after every run.
find "$ROOT" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
