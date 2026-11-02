# Agent Workspace 1

Reusable, disposable code execution and verification for agents.

## Run a task
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

See [architecture](docs/architecture.md), [security](docs/security.md), [task contract](docs/task-contract.md), [Supabase Task Ledger integration](docs/task-ledger-integration.md), and [ChatGPT goal/worker protocol](docs/chat-agent-workflow.md).\n\n## Agent tools and skills\n- [Looper](tools/looper/README.md): bounded loop-state controller for agent iterations.\n- [Tools catalogue](tools/catalog/README.md): curated AI coding, linting, testing and browser tools.\n- [Skills catalogue](skills/catalog.json): versioned snapshot of all 29 skills backed up from the Skills Database, including linked tool references.\n- [Loop Generator skill](skills/loop-generator/SKILL.md): uses Looper to persist iteration inputs, outputs and stop decisions.

## Local
```bash
python runner/execute.py --task-file examples/python-smoke.json
python runner/verify.py --result results/execution.json
```

Public-repository rule: never commit secrets, private source or personal data. This runner is not a hardened hostile multi-tenant sandbox. Hosted VMs are ephemeral; persist required outputs as artifacts.
