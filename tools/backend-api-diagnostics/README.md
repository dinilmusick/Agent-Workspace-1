# Backend and API diagnostics

The API diagnostics runner exercises a real application listening on the local inspection runner. It uses Node.js built-ins only and does not introduce another runtime or install target dependencies.

## Run

```bash
node tools/backend-api-diagnostics/scripts/run-api-diagnostics.mjs \
  --manifest workspaces/target/.agent-workspace/api-tests.json \
  --output artifacts/api
```

Set `API_BASE_URL` to a local base URL or provide `baseUrl` in the manifest. The runner only accepts `localhost`, `127.0.0.1` or `::1` to prevent target manifests from using the hosted runner to probe external services. `SERVER_LOG_PATH` may point to newline-delimited structured server logs.

## Manifest contract

Copy [the example manifest](examples/api-tests.json) to `.agent-workspace/api-tests.json` in the target repository.

- `version`: currently `1`.
- `baseUrl`: optional local server URL; overridden by `API_BASE_URL`.
- `timeoutMs`: default request timeout.
- `requests`: ordered scenarios with `id`, `method`, relative `path`, `headers`, optional `body`, `timeoutMs` and `expect`.
- `expect.status`: expected status or list of acceptable statuses.
- `expect.headers`: response header equality checks.
- `expect.jsonSchema`: supported JSON Schema subset: type, required, properties, items and enum.
- `expect.jsonPath`: dotted JSON property equality checks.
- Header/body values may use `{"$env":"VARIABLE_NAME"}` to read a runner environment variable. Never place literal credentials in a manifest.

## Correlation and evidence

Every request sends a unique `x-correlation-id`. The runner accepts a matching `x-correlation-id` or `x-request-id` response header and associates JSONL server log records whose `correlationId`, `correlation_id`, `requestId`, `request_id` or `request.id` matches the request ID. Server logs should emit one structured JSON object per line and include exception metadata for failed requests.

Artifacts:

- `api-diagnostics.json`: request/response metadata, timing, assertions, redacted headers/body and correlated server log records.
- `api-diagnostics.md`: concise human-readable scenario summary.

Authorization, cookie, token, secret, password and API-key fields are redacted recursively. Non-JSON response bodies are omitted. Request paths are constrained to the configured local origin. Timeouts cover response headers and body consumption.

## CI integration

`inspect-react.yml` runs the API suite only when the target repository contains `.agent-workspace/api-tests.json`, after the local app is ready. The runner consumes `artifacts/build/dev-server.log` for correlation and writes into `artifacts/api`; the existing inspection artifact upload retains both API and browser evidence. API failures fail the inspection job.

The toolchain CI runs the built-in Node regression suite against a local HTTP server. This verifies runner behavior; it does not claim to validate any particular target application's API contract.
