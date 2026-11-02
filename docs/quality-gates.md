# Security and quality gates

The reusable quality contract lives in the target application's \`.agent-workspace/quality-gates.json\`. The checked-in sample at \`examples/quality-sample\` is a real Node HTTP application used to exercise the gates, not a static page fixture.

## Automated checks

| Gate | Implementation | Failure policy |
|---|---|---|
| Dependency vulnerabilities | \`npm audit\`, Trivy filesystem scan; optional GitHub Dependency Review when repository dependency graph is enabled | High or critical |
| Secret detection | Gitleaks full Git-history scan; Trivy secret scanner | Any confirmed finding |
| Static security | CodeQL JavaScript/TypeScript and Python, security-extended queries | SARIF security severity 7+ |
| Container security | Trivy Dockerfile/config scan and built-image scan | High or critical, ignoring unfixed CVEs |
| API authorization | Existing Backend/API Diagnostics runner | Exact expected status, schema and correlation-log checks |
| Coverage | Vitest V8 coverage plus the generic Istanbul summary gate | Per-project line, statement, function and branch thresholds |
| Lighthouse | Lighthouse CLI 13.4.1 against the running application | Category scores and metric budgets |

CodeQL SARIF is retained as a workflow artifact instead of being uploaded to GitHub Code Scanning, so the gate does not require GitHub Advanced Security. Gitleaks, Trivy and npm audit reports are also retained.

## Configure a target

Copy the sample manifest and adjust thresholds:

\`\`\`json
{
  "version": 1,
  "baseUrl": "http://127.0.0.1:4173",
  "coverage": {
    "summaryFile": "artifacts/coverage/coverage-summary.json",
    "thresholds": {
      "lines": 85,
      "statements": 85,
      "functions": 85,
      "branches": 75
    }
  },
  "security": {
    "npmAuditLevel": "high",
    "staticSeverity": { "high": 7, "critical": 9 },
    "trivySeverity": ["HIGH", "CRITICAL"],
    "ignoreUnfixed": true
  },
  "lighthouse": {
    "enabled": true,
    "urls": ["/", "/about"],
    "numberOfRuns": 2,
    "categoryThresholds": {
      "performance": 0.9,
      "accessibility": 0.9,
      "best-practices": 0.9,
      "seo": 0.9
    },
    "metricBudgets": {
      "first-contentful-paint": 1800,
      "largest-contentful-paint": 2500,
      "total-blocking-time": 200,
      "cumulative-layout-shift": 0.1,
      "speed-index": 3000,
      "total-byte-weight": 300000
    }
  }
}
\`\`\`

Coverage thresholds are percentages from the Istanbul \`coverage-summary.json\` format. Lighthouse metric budgets use the numeric values reported by Lighthouse (milliseconds for paint/blocking metrics, unitless for CLS, bytes for \`total-byte-weight\`). The gate aggregates repeated runs using average category scores and median metric values.

Keep credentials out of manifests and source files. API test request bodies and headers support environment expansion through the existing diagnostics runner; set those variables in the workflow environment or a secret store.

## Run locally

From the repository root, with the canonical toolchain installed:

\`\`\`bash
npm ci --prefix tools/react-typescript-fullstack
QUALITY_TARGET_ROOT=examples/quality-sample \
QUALITY_GATES_MANIFEST=examples/quality-sample/.agent-workspace/quality-gates.json \
tools/react-typescript-fullstack/node_modules/.bin/vitest run \
  --config tools/react-typescript-fullstack/vitest.quality.config.mjs --coverage
QUALITY_TARGET_ROOT=examples/quality-sample \
QUALITY_GATES_MANIFEST=examples/quality-sample/.agent-workspace/quality-gates.json \
node tools/react-typescript-fullstack/scripts/quality/coverage-gate.mjs
\`\`\`

For Lighthouse, start the target application, install Chromium with Playwright, set \`CHROME_PATH\` to the installed Chromium executable and set \`QUALITY_BASE_URL\`. Then run \`node tools/react-typescript-fullstack/scripts/quality/lighthouse-gate.mjs\`.

## CI artifacts

\`quality-gates.yml\` runs the repository security job and a real application quality job. The latter copies the sample into \`workspaces/target\`, prepares and starts it with the canonical React project runner, runs API authorization diagnostics, enforces coverage, audits Lighthouse and stops the process group.

Artifacts include npm audit JSON, Gitleaks/Trivy/CodeQL SARIF, API diagnostics, coverage JSON/LCOV, Lighthouse JSON/HTML, build logs and the quality summary. They are retained for 14 days.
