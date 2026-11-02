# Architecture

## Responsibilities

1. **Task manifest** — declares the command, working directory, timeout and non-secret environment values.
2. **GitHub Actions** — provisions a fresh hosted VM, checks out the repository and invokes the runner.
3. **Execution runner** — validates the manifest, launches the process without a shell, bounds execution time and captures output.
4. **Result verifier** — validates the machine-readable evidence contract independently of task success.
5. **Artifact store** — preserves result JSON and any files placed under `results/` for 14 days.

## Execution sequence

```text
Caller / Agent
    |
    | workflow_dispatch(task_file, runner)
    v
GitHub Actions
    |
    +--> ephemeral hosted VM
    |
    +--> checkout repository
    |
    +--> runner/execute.py
    |       |
    |       +--> validate manifest and workspace paths
    |       +--> spawn argv with shell=False
    |       +--> enforce timeout
    |       +--> capture stdout/stderr/exit code
    |       +--> write results/execution.json
    |
    +--> runner/verify.py
    |
    +--> upload execution-result artifact
    |
    v
Caller polls workflow and downloads artifact
```

## Extension points

- Add language-specific task examples and setup scripts.
- Add a Playwright task profile that installs pinned browser dependencies and uploads HTML reports, screenshots and traces.
- Add build adapters for Rust, Go, Java, .NET and application-specific toolchains.
- Add a dispatcher service that creates workflow-dispatch requests, polls run status and downloads artifacts.
- Persist task state, claims, retries and verification decisions in a separate coordination database. GitHub Actions should remain an execution provider, not the system of record.

## Design decisions

- One execution request maps to one fresh hosted VM.
- The task command is an argv array; the runner never evaluates a shell command string.
- The workflow accepts only a repository task manifest path.
- The task process receives no GitHub Actions token or workflow secrets.
- Task execution is manually dispatched by default. Repository validation does not execute arbitrary task manifests.
- The selected runner image is explicit in workflow input; pin tool versions in the project/task itself for reproducibility.
