#!/usr/bin/env bash
set -uo pipefail

TARGET_DIR="${1:?target directory required}"
LOG_FILE="${2:?log file required}"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee "$LOG_FILE") 2>&1

cd "$TARGET_DIR"
failures=()
checks=()

echo "=== Native GitHub runner verification ==="
echo "Repository: ${TARGET_REPOSITORY:-unknown}"
echo "Ref: ${TARGET_REF:-unknown}"
echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo "Runner: ${RUNNER_OS:-unknown} / ${ImageOS:-unknown}"
echo "Node: $(node --version 2>/dev/null || echo unavailable)"
echo "Python: $(python3 --version 2>/dev/null || echo unavailable)"
echo

run_check() {
  local label="$1"; shift
  echo "::group::$label"
  echo "+ $*"
  "$@"
  local status=$?
  echo "::endgroup::"
  checks+=("$label:$status")
  if [[ $status -ne 0 ]]; then
    failures+=("$label (exit $status)")
    echo "::error::$label failed with exit code $status"
  else
    echo "PASS: $label"
  fi
}

has_script() {
  node -e 'const p=require(process.argv[1]); process.exit(p.scripts && p.scripts[process.argv[2]] ? 0 : 1)' "$TARGET_DIR/package.json" "$1" >/dev/null 2>&1
}

PM=""
if [[ -f package.json ]]; then
  PM="$(node -p "require('./package.json').packageManager || ''" 2>/dev/null || true)"
  if [[ "$PM" == pnpm@* ]] || [[ -f pnpm-lock.yaml ]]; then
    corepack enable
    if [[ "$PM" == pnpm@* ]]; then corepack prepare "$PM" --activate; fi
    if [[ -f pnpm-lock.yaml ]]; then
      run_check "dependency-install" pnpm install --frozen-lockfile
    else
      run_check "dependency-install" pnpm install --no-frozen-lockfile
    fi
  elif [[ "$PM" == yarn@* ]] || [[ -f yarn.lock ]]; then
    corepack enable
    if [[ "$PM" == yarn@* ]]; then corepack prepare "$PM" --activate; fi
    if [[ "$PM" == yarn@* ]] && [[ "${PM#yarn@}" == 1.* ]]; then
      run_check "dependency-install" yarn install --frozen-lockfile
    else
      run_check "dependency-install" yarn install --immutable
    fi
  elif [[ "$PM" == bun@* ]] || [[ -f bun.lock ]] || [[ -f bun.lockb ]]; then
    echo "::error::Bun project detected; this runner currently requires a Bun-specific toolchain."
    exit 2
  elif [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
    run_check "dependency-install" npm ci
  else
    run_check "dependency-install" npm install
  fi
  install_status=${checks[0]##*:}
  if [[ "$install_status" != "0" ]]; then
    echo "::error::Dependency installation failed; downstream checks cannot be trusted."
    exit 1
  fi
fi

# Install Python project/test dependencies without passing any GitHub credentials
# into target scripts or subprocesses.
if [[ -f requirements.txt ]]; then
  run_check "python-requirements" python3 -m pip install --disable-pip-version-check -r requirements.txt
fi
if [[ -f requirements-dev.txt ]]; then
  run_check "python-dev-requirements" python3 -m pip install --disable-pip-version-check -r requirements-dev.txt
fi
if [[ -f pyproject.toml ]] && [[ ! -f requirements.txt ]] && [[ ! -f requirements-dev.txt ]]; then
  run_check "python-project-install" python3 -m pip install --disable-pip-version-check -e .
fi
if find . -path './node_modules' -prune -o -name '*.py' -print -quit | grep -q .; then
  python3 -m pip show pytest >/dev/null 2>&1 || run_check "pytest-install" python3 -m pip install --disable-pip-version-check pytest
fi

if [[ -f package.json ]]; then
  if [[ "$PM" == pnpm@* ]] || [[ -f pnpm-lock.yaml ]]; then PKG=(pnpm run); else PKG=(npm run); fi
  for name in lint typecheck build test validate boundary boundary:clean-room boundary:relative architecture:check test:public-exports test:published test:architecture-boundary; do
    if has_script "$name"; then
      run_check "script-$name" "${PKG[@]}" "$name"
    else
      echo "SKIP: package script '$name' is not defined"
    fi
  done
else
  echo "No package.json; no Node package scripts were discovered."
fi

{
  echo "### ${TARGET_REPOSITORY:-Repository} — native runner"
  echo "- Ref: ${TARGET_REF:-unknown}"
  echo "- Commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  for item in "${checks[@]}"; do
    name="${item%:*}"; status="${item##*:}"
    if [[ "$status" == "0" ]]; then echo "- PASS: $name"; else echo "- FAIL: $name (exit $status)"; fi
  done
  if [[ ${#failures[@]} -eq 0 ]]; then
    echo "- Result: **PASS**"
  else
    echo "- Result: **FAIL**"
    for item in "${failures[@]}"; do echo "- Failure: $item"; done
  fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "::error::Verification failed: ${failures[*]}"
  exit 1
fi

echo "All discovered native checks passed."
