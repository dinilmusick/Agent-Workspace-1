#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${TARGET_REPOSITORY:?TARGET_REPOSITORY must be owner/name or a GitHub URL}"

ROOT="${CLONE_ROOT:-${GITHUB_WORKSPACE}/clones}"
REF="${TARGET_REF:-}"
mkdir -p "$ROOT"

repo="$TARGET_REPOSITORY"
repo="${repo#https://github.com/}"
repo="${repo#git@github.com:}"
repo="${repo%.git}"
repo="${repo%%/*}/${repo#*/}"
owner="${repo%%/*}"
name="${repo#*/}"
slug="${owner}__${name}"

if [[ -z "$owner" || -z "$name" || "$owner" == "$name" ]]; then
  echo "Invalid TARGET_REPOSITORY: $TARGET_REPOSITORY" >&2
  exit 2
fi

DEST="$ROOT/$slug"
rm -rf "$DEST"

URL="https://x-access-token:${GITHUB_TOKEN}@github.com/$owner/$name.git"
if [[ -n "$REF" ]]; then
  git clone --depth 1 --branch "$REF" "$URL" "$DEST"
else
  git clone --depth 1 "$URL" "$DEST"
fi

# Never leave the access token in the cloned repository's git config.
git -C "$DEST" remote set-url origin "https://github.com/$owner/$name.git"
git -C "$DEST" remote set-url --push origin "https://github.com/$owner/$name.git"

printf '%s\n' "$DEST"
