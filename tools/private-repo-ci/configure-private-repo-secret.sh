#!/usr/bin/env bash
set -euo pipefail

# Configure a GitHub Actions repository secret containing a read-capable token
# for private-repository fallback CI.
#
# Local usage:
#   bash tools/private-repo-ci/configure-private-repo-secret.sh
#
# The default token source is the authenticated GitHub CLI session:
#   gh auth token
#
# For CI/non-interactive use, provide PRIVATE_REPO_TOKEN explicitly.
# Never pass the token as a command-line argument.

REPOSITORY="${AGENT_WORKSPACE_REPOSITORY:-dinilmusick/Agent-Workspace-1}"
SECRET_NAME="${PRIVATE_REPO_SECRET_NAME:-PRIVATE_REPO_TOKEN}"

command -v gh >/dev/null 2>&1 || {
  echo "GitHub CLI (gh) is required." >&2
  exit 127
}

if [[ -z "${PRIVATE_REPO_TOKEN:-}" ]]; then
  if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    echo "PRIVATE_REPO_TOKEN must be explicitly provided in GitHub Actions." >&2
    echo "Refusing to use GITHUB_TOKEN because it is scoped to the current repository." >&2
    exit 2
  fi

  gh auth status >/dev/null 2>&1 || {
    echo "No authenticated GitHub CLI session. Run: gh auth login" >&2
    exit 1
  }

  TOKEN="$(gh auth token)"
else
  TOKEN="$PRIVATE_REPO_TOKEN"
fi

if [[ -z "$TOKEN" ]]; then
  echo "No GitHub token was available." >&2
  exit 1
fi

# Read the token from stdin so it never appears in the process argument list.
printf '%s' "$TOKEN" |
  gh secret set "$SECRET_NAME" --repo "$REPOSITORY"

unset TOKEN PRIVATE_REPO_TOKEN

echo "Configured repository secret '$SECRET_NAME' on '$REPOSITORY'."
echo "The secret value was not printed or written to the repository."
