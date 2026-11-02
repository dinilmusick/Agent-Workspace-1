# Workspace and permanent tools

## Storage boundary

`workspaces/` is the disposable experiment area. Agent Compute checks the selected source revision out to a temporary workspace during each run. It is not committed or treated as canonical source. GitHub-hosted runners are ephemeral; required outputs are uploaded as workflow artifacts.

`tools/` is the permanent, version-controlled tool catalogue. Tool source, pinned dependencies, environment manifests, scripts, test fixtures and tool documentation live here.

## Current layout

```text
.github/workflows/
  agent-compute.yml             # sole general-purpose finite compute workflow
  inspect-react.yml             # rendered React/browser inspection
  validate-browser-harness.yml  # real preview E2E, accessibility and visual baselines
  validate-workspace.yml        # repository and compute validation
  validate-toolchain.yml        # pinned toolchain validation
runner/
  execute-code.py               # language-aware compute executor
  resolve-compute-request.py    # validates workflow/issue requests
  checkout-public-repository.py # public target checkout helper
  react-project.py              # React project preparation and checks
  service-runtime.py            # concurrent local service supervisor
  test_service_runtime.py       # multi-service lifecycle regression tests
tools/
  looper/
  react-typescript-fullstack/    # Playwright Test, route discovery and browser evidence
  backend-api-diagnostics/       # local API contract, auth and server-log diagnostics
  agent-runtimes/
examples/
  services.json                  # multi-service target manifest example
  fixture-service.py             # multi-service lifecycle test fixture
  browser-sample/                # real app for browser E2E and visual validation
workspaces/                     # disposable target checkout area
results/                        # compute output area
```

## Rules

1. Never commit checked-out application repositories under `workspaces/`.
2. Never store credentials, private source or personal data in this public repository.
3. Tools are permanent; workspaces and hosted runners are disposable.
4. Compute accepts an explicit source file and runtime; it does not use task manifests.
5. Do not execute untrusted target code with repository write permissions or secrets.
