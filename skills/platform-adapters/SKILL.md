# Platform Development Adapters

## Purpose

Route platform-specific development checks through one local-only adapter contract. The adapters run in ephemeral development/CI environments and produce machine-readable summaries plus provider logs under `artifacts/platforms/`.

## Supported providers

### Cloudflare Workers

- Use the current `@cloudflare/vitest-plugin` with Vitest, Vite and Wrangler. Vitest 5 requires Vite as a direct peer dependency.
- The plugin runs tests in the local Workers runtime (Miniflare/workerd) and loads real bindings from `wrangler.jsonc`/Wrangler configuration.
- Test binding access through `env` from `cloudflare:workers` and call the Worker entry point through `exports.default.fetch()`.
- The fixture explicitly allows only the pinned `esbuild@0.28.2` and `workerd@1.20261101.1` install scripts required by the local runtime; do not blanket-allow dependency scripts.
- Do not introduce the legacy `@cloudflare/vitest-pool-workers` package for new integrations.
- Run the target project's installed Vitest binary; do not deploy the Worker.

### Vercel

- A linked project with `VERCEL_TOKEN` can run `vercel pull --environment=preview` followed by `vercel build`. This builds locally using preview environment variables; it does not deploy.
- An explicitly supplied `VERCEL_PREVIEW_URL` can be inspected with `vercel inspect`, build logs with `vercel inspect --logs`, a route smoke check with `vercel curl`, and runtime errors with `vercel logs --deployment ... --level error --json`.
- The URL must be HTTPS on `*.vercel.app`. The adapter refuses a deployment identified as Production and requires an explicit Preview assertion if the CLI output omits its target.
- Without a token, a public preview URL receives an HTTP smoke check only; authenticated build/runtime diagnostics are marked unavailable.
- Never invoke `vercel deploy`, `vercel redeploy`, `vercel promote`, or production-target commands from this adapter.
- The adapter removes `.vercel/.env.preview.local` after the local build and redacts tokens from logs.

### Supabase local database

- Require Supabase CLI v3.
- Start a local Postgres-only stack by excluding Auth, Realtime, Storage, Studio, Edge Runtime, Analytics, Vector and other non-database services.
- Run `supabase db reset --yes` to recreate the disposable local database and apply migrations, then `supabase test db --yes` for local pgTAP tests when present. `--yes` is permitted only because the adapter has stripped remote credentials and uses the local target.
- Always stop the local stack after the run, including when migration/tests fail.
- Strip Supabase access tokens, project refs and database passwords from the adapter process environment. No `supabase link`, remote DB, `--linked`, `--remote`, Edge Function or deployment command is permitted.

## Shared interface

```bash
python runner/platform_adapters.py all --project-path workspaces/target --output-dir artifacts/platforms
python runner/platform_adapters.py cloudflare --project-path workspaces/target
python runner/platform_adapters.py vercel --project-path workspaces/target
python runner/platform_adapters.py supabase --project-path workspaces/target
```

Provider discovery is based on `wrangler.jsonc`/Wrangler TOML, `vercel.json` or `.vercel/project.json`, and `supabase/config.toml`. Missing providers are reported as skipped, not failed.

Artifacts:

- `platform-adapters.json`: provider status and skip reasons.
- `cloudflare-vitest.log`: Worker-runtime test output.
- `vercel-pull.log`, `vercel-build.log`, `vercel-inspect.log`, `vercel-build-logs.log`, `vercel-preview-curl.log`, `vercel-runtime-errors.jsonl`, and `vercel-preview-http.json`: available local/preview diagnostics.
- `supabase-version.log`, `supabase-start.log`, `supabase-migrations.log`, `supabase-pgtap.log`, and `supabase-stop.log`: local database test evidence.

## Safety boundary

These adapters are for local builds, preview inspection and local database migrations/tests only. They are not deployment tooling. Supabase remains the persistent task/skill ledger; the Supabase CLI adapter starts an isolated local database and never connects to the ledger project.

## Private GitHub adapter

When a private GitHub repository requires workflow execution and native private CI is unavailable, exhausted, or blocked, use private-repo-ci-workspace-runner through Agent-Workspace-1.

privateGitHub → AgentWorkspace1 → clone → validate → act → evidence → cleanup

This adapter should be used extensively for private-repository verification. Never pass write/deployment credentials to target workflows.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.