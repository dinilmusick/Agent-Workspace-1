# Workspace and permanent tools

## Storage boundary

`workspaces/` is the disposable experiment area. The workflow checks a target repository out to `workspaces/target/` for one run. It is not committed, packaged into the tools, or treated as canonical source. GitHub-hosted runners are ephemeral, so required outputs are uploaded as workflow artifacts.

`tools/` is the permanent, version-controlled tool catalogue. Tool source, pinned dependencies, environment manifests, scripts, test fixtures and tool documentation live here. Tools operate on a workspace path supplied by the task; they must not assume a particular application repository.

## Current layout

```text
workspaces/
  .gitkeep
  target/                         # created at runtime; ignored by git
tools/
  react-typescript-fullstack/
    environment.json
    package.json
    README.md
    scripts/
      inspect.mjs
runner/
  checkout-public-repository.py
  react-project.py
  execute.py
  verify.py
inspectors/                        # future shared inspectors
tasks/                             # task manifests
artifacts/                         # runtime evidence; uploaded per run
```

## Rules

1. Never commit checked-out application repositories under `workspaces/`.
2. Never store credentials, private source, or personal data in this public repository.
3. Tools are permanent; workspaces are disposable.
4. A tool accepts an explicit workspace/project path and emits evidence under `artifacts/`.
5. Keep environment detection and tool selection declarative in each environment manifest.
6. Do not execute untrusted target code with repository write permissions or secrets.
