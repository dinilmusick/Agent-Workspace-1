# Multi-service application runtime

The canonical application entry point remains `runner/react-project.py`. It retains the existing single-process behavior for targets without a service manifest and delegates manifest-based applications to the Python standard-library supervisor in `runner/service-runtime.py`.

## Enable multiple services

Add `.agent-workspace/services.json` to the target application repository:

```json
{
  "version": 1,
  "services": [
    {
      "id": "api",
      "command": ["python", "server.py"],
      "cwd": ".",
      "port": 4174,
      "port_env": "PORT",
      "host_env": "HOST",
      "env": { "APP_ENV": "inspection" },
      "healthcheck": { "type": "http", "path": "/health", "interval_seconds": 2 },
      "restart": { "policy": "on-failure", "max_restarts": 2, "delay_seconds": 1 },
      "shutdown_grace_seconds": 5
    },
    {
      "id": "web",
      "command": ["npm", "run", "dev", "--", "--host", "127.0.0.1", "--port", "${service.web.port}"],
      "cwd": ".",
      "port": 4173,
      "port_env": "PORT",
      "env": { "API_BASE_URL": "http://127.0.0.1:${service.api.port}" },
      "healthcheck": { "type": "http", "path": "/", "interval_seconds": 2 },
      "restart": { "policy": "on-failure", "max_restarts": 1 }
    }
  ]
}
```

Use argv arrays, not shell command strings. Service IDs may contain letters, digits, hyphens and underscores. Working directories are resolved beneath the checked-out target root; path traversal is rejected. All services launch concurrently.

- `port: 0` requests an available local TCP port; the assigned value is injected through `port_env` (default `PORT`).
- `env` values support `${service.<id>.port}` and `${service.<id>.url}` references.
- Health checks support `process`, `tcp` and `http`; HTTP/TCP checks require a port.
- Restart policy is `never`, `on-failure` or `always`, with bounded `max_restarts` and optional `delay_seconds`.
- `shutdown_grace_seconds` bounds graceful process-group termination before SIGKILL.

## Lifecycle

```text
react-project.py start
       |
       v
service-runtime.py start
       |
       +--> spawn API / database dependency / frontend concurrently
       +--> wait for each readiness check
       +--> publish state.json and assigned ports
       +--> supervise exits and health checks
       |
inspect-react waits on frontend port 4173
       |
Playwright + API diagnostics
       |
react-project.py stop
       |
SIGTERM process groups -> grace period -> SIGKILL if required
```

The workflow always invokes `react-project.py stop` after inspection, then uploads the per-service logs and state with the other artifacts.

## Local commands

From the Agent Workspace repository, with a target checked out under `workspaces/target`:

```bash
python runner/react-project.py start --project-path .
python runner/react-project.py status --project-path .
python runner/react-project.py stop --project-path .
```

The lower-level supervisor supports `start`, `status` and `stop` and writes:

- `artifacts/services/state.json`: supervisor state, service PID, assigned port, readiness, restart count and log path.
- `artifacts/services/<service-id>.log`: stdout and stderr for that service.
- `artifacts/services/supervisor.log`: supervisor diagnostics.

No Docker daemon, Supabase Edge Function or Supabase compute is required. The runtime is local to the ephemeral GitHub Actions runner; Supabase remains the persistent coordination ledger only.
