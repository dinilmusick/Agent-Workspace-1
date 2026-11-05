#!/usr/bin/env bash
set -euo pipefail

: "${CLONED_REPO:?CLONED_REPO is required}"

EVENT="${CI_EVENT:-push}"
WORKFLOW="${CI_WORKFLOW:-}"
ACT_BIN="${ACT_BIN:-act}"

cd "$CLONED_REPO"

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
  "$ACT_BIN" "$EVENT" -W "$wf" --artifact-server-path /tmp/agent-workspace-artifacts "${ACT_SECRET_ARGS[@]}"
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
