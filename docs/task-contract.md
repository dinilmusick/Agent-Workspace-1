# Task manifest contract

A manifest is a UTF-8 JSON object stored in the repository.

## Fields

| Field | Required | Meaning |
|---|---|---|
| `version` | Yes | Contract version; currently `1` |
| `name` | No | Human-readable task label |
| `command` | Yes | Non-empty argv array; no shell parsing |
| `cwd` | No | Existing directory relative to repository root; default `.` |
| `timeout_seconds` | No | Integer from 1 to 1800; default 300 |
| `env` | No | Up to 32 explicit non-secret string environment values |

## Example

```json
{
  "version": 1,
  "name": "unit-tests",
  "command": ["python", "-m", "unittest", "discover", "-s", "tests"],
  "cwd": ".",
  "timeout_seconds": 300,
  "env": {
    "APP_MODE": "test"
  }
}
```

## Result schema

The runner writes `results/execution.json` with:

- `schema_version`
- `status`: `success`, `failed`, `timed_out` or `error`
- `task_file`, `task_name`, `command`, `cwd`
- `started_at`, `completed_at`, `duration_seconds`
- `exit_code`, `timed_out`
- `stdout`, `stderr`, `error`

A valid result contract does not mean the task passed. Consumers must inspect `status` and `exit_code`.
