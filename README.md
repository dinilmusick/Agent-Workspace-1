# Agent Workspace 1

Reusable, disposable execution, verification and agent-task infrastructure.

## Chat-driven multi-agent goals

The primary multi-agent workflow uses separate ChatGPT browser conversations that you open manually:

1. Discuss a goal with an orchestrator conversation.
2. The orchestrator creates a persistent, versioned goal and a dependency-aware task tree in Supabase.
3. Every task receives a mandatory Loop Generator contract.
4. The orchestrator reports how many additional worker chats are useful.
5. Each manually opened worker chat claims one eligible task from the named goal, executes its persisted loop and records evidence.
6. The orchestrator independently verifies results, runs parent-task loops and finalizes the goal.

No GitHub workflow spawns ChatGPT conversations. Supabase PostgreSQL provides persistence and atomic coordination; GitHub provides source control, CI and finite execution jobs.

See [ChatGPT goal workflow](docs/chat-agent-workflow.md), [Task Ledger integration](docs/task-ledger-integration.md), and [Task Ledger skill](skills/task-ledger/SKILL.md).

## GitHub-hosted execution

1. Add code and a JSON manifest under `examples/` or `tasks/`.
2. Open Actions → Execute Task → Run workflow.
3. Supply the manifest path and runner image.
4. Download the `execution-result` artifact from the completed run.

A manifest declares an argv array (never a shell string):

```json
{"version":1,"name":"python-smoke","command":["python","examples/hello.py"],"cwd":".","timeout_seconds":60}
```

## Capabilities

- On-demand Python, Node.js, shell and other installed toolchains.
- Fresh GitHub-hosted VM per execution.
- Timeout, bounded stdout/stderr, exit code and JSON evidence.
- Artifact upload and independent result-contract validation.
- Separate repository validation that never executes task manifests.
- Browser inspection and Looper-based iteration tooling.

See [architecture](docs/architecture.md), [security](docs/security.md), [task contract](docs/task-contract.md), [Looper](tools/looper/README.md), and [tools catalogue](tools/catalog/README.md).

## Local

```bash
python runner/execute.py --task-file examples/python-smoke.json
python runner/verify.py --result results/execution.json
```

Public-repository rule: never commit secrets, private source or personal data. This runner is not a hardened hostile multi-tenant sandbox. Hosted VMs are ephemeral; persist required outputs as artifacts.
