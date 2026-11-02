# Agent Compute request contract

Agent Compute runs one source file from a selected repository revision on an ephemeral GitHub-hosted Ubuntu runner.

## Inputs

| Field | Required | Meaning |
|---|---|---|
| `ref` | Yes | Branch, tag or commit containing the source file |
| `runtime` | Yes | `python`, `node`, `typescript`, `bash`, `go`, `rust`, `java`, `c`, `cpp`, `csharp`, `ruby`, `php`, `perl`, `r` or `powershell` |
| `source_file` | Yes | Repository-relative source file path |
| `arguments` | No | JSON array of string arguments; defaults to `[]` |
| `timeout_seconds` | No | Integer from 1 to 1,200; defaults to 300 |

## Invocation

### Workflow dispatch

Run `.github/workflows/agent-compute.yml` and provide the inputs above.

### Issue route

When workflow dispatch is unavailable to the agent connector, create an issue with title:

```text
[agent-compute] <goal-key> <runtime>
```

Issue body:

```json
{
  "ref": "main",
  "runtime": "python",
  "source_file": "workspaces/example.py",
  "arguments": [],
  "timeout_seconds": 300
}
```

The issue route accepts only repository owners, members and collaborators.

## Outputs

The workflow uploads `compute-result.json` and files written under `results/` as a run artifact. Inspect the workflow result and artifact before reporting execution success.

## Isolation

The runner is ephemeral, uses read-only repository permissions, does not persist checkout credentials and receives no application secrets. It is finite compute, not a persistent development machine or a ChatGPT worker.
