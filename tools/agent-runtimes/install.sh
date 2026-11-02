#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME_DIR="$ROOT/tools/agent-runtimes"
npm ci --prefix "$RUNTIME_DIR" --ignore-scripts --no-audit --no-fund
python3 -m pip install --user -r "$RUNTIME_DIR/requirements.txt"
printf '\nAgent loop runtimes installed. Verify each CLI is authenticated before selecting it.\n'
"$RUNTIME_DIR/node_modules/.bin/agent-loop" --help
autohelix --help
