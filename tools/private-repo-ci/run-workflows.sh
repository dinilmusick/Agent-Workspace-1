#!/usr/bin/env bash
set -euo pipefail

: "${CLONED_REPO:?CLONED_REPO is required}"

EVENT="${CI_EVENT:-push}"
REF="${TARGET_REF:-}"
WORKFLOW="${CI_WORKFLOW:-}"
ACT_BIN="${ACT_BIN:-act}"
# Loky CI currently targets ubuntu-24.04. Map that GitHub runner label to the
# pinned act image so the workspace executes the workflow instead of silently
# skipping an unsupported platform. Callers can override this explicitly.
ACT_PLATFORM="${ACT_PLATFORM:-ubuntu-24.04=catthehacker/ubuntu:act-latest}"
ACT_GITHUB_TOKEN="${ACT_GITHUB_TOKEN:-}"
ACT_SECRET_ARGS=()

if [[ -n "$ACT_GITHUB_TOKEN" ]]; then
  ACT_SECRET_ARGS+=(--secret "GITHUB_TOKEN=$ACT_GITHUB_TOKEN")
fi

cd "$CLONED_REPO"
if [[ -n "$REF" ]]; then
  actual="$(git rev-parse HEAD)"
  expected="$(git rev-parse "$REF" 2>/dev/null || true)"
  if [[ -n "$expected" && "$actual" != "$expected" ]]; then
    echo "Clone ref verification failed: expected $REF ($expected), got $actual" >&2
    exit 3
  fi
fi

if ! command -v "$ACT_BIN" >/dev/null 2>&1; then
  echo "act is required. Install it on local agents or use the public Agent-Workspace CI workflow." >&2
  exit 127
fi

mapfile -t workflows < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

if [[ ${#workflows[@]} -eq 0 ]]; then
  echo "No GitHub Actions workflow definitions found."
  exit 0
fi

run_one() {
  local wf="$1"
  echo "::group::CI workflow $wf"
  "$ACT_BIN" "$EVENT" \
    -W "$wf" \
    --platform "$ACT_PLATFORM" \
    --artifact-server-path /tmp/agent-workspace-artifacts \
    "${ACT_SECRET_ARGS[@]}"
  echo "::endgroup::"
}

if [[ -n "$WORKFLOW" ]]; then
  [[ -f ".github/workflows/$WORKFLOW" ]] || { echo "Workflow not found: $WORKFLOW" >&2; exit 2; }
  run_one ".github/workflows/$WORKFLOW"
else
  for wf in "${workflows[@]}"; do
    run_one "$wf"
  done
fi
