# Agent Workspace instructions

## Entry routing
1. Treat ordinary conversation as conversation; do not invoke a skill automatically.
2. For an actionable goal, read `skills/universal-task-router/SKILL.md`.
3. Use `skills/current-versions.json` and Supabase `public.skills.current_version_id` to resolve current skill versions.
4. For coding goals, activate `skills/coding-router/SKILL.md` and its narrow specialist skills.
5. For multi-stage or ambiguous goals, use Prompt Map; for repeated action/verification, use Loop Generator and Looper.
6. For multi-agent work, use Task Ledger in Supabase as the shared source of truth.

## Skill and tool catalogue
- `skills/<slug>/SKILL.md`: individual skill definitions mirrored from Supabase.
- `skills/registry.json`: skill catalogue snapshot.
- `skills/current-versions.json`: current version overrides.
- `skills/tool-bindings.json`: tools and skill bindings.
- `skills/optional-agent-bindings.json`: optional IDE/self-hosted agent backends.
- Supabase `public.skill_tools` and `public.skill_tool_links` are canonical for tool metadata and bindings.
- Do not infer tool availability from registration. Verify the connector, CLI, permissions and authentication before use.

## Workspace boundaries
- `workspaces/`: disposable target repositories and experiments. Never commit target application code here.
- `tools/`: permanent, version-controlled scripts, package manifests, lockfiles and tool adapters.
- `runner/`: repository checkout, project preparation/start and execution helpers.
- `artifacts/`: build, test, quality and browser evidence; upload artifacts from CI.
- Do not place credentials, private source or user secrets in this public repository.

## Supabase Task Ledger
- The authenticated integration is deployed as Supabase Edge Function `task-ledger`.
- Use `runner/task-ledger.mjs` for authenticated API calls; configure `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and a dedicated agent's `SUPABASE_AGENT_JWT`.
- Each manually opened ChatGPT conversation uses the connected Supabase connector and a unique conversation-scoped agent_id; it does not need its own Supabase Auth user. The optional standalone CLI/GitHub runner requires a Supabase Auth user and enabled public.agent_registry row. The service-role key must never be placed in an agent runtime.
- Orchestrators create task trees; workers claim tasks using leases; every claim-bound write requires the returned claim token; verifier workers inspect pending results and iteration evidence, independently accept/reject results, and finalize ancestors only after all children are verified.
- Worker entrypoints: `runner/agent-worker.mjs` and `runner/verifier-worker.mjs`; both require a dedicated registered Supabase Auth identity and a runtime adapter contract.
- Follow `docs/task-ledger-integration.md` for provisioning and command examples.

## Looper
Use:
```bash
node tools/looper/looper.mjs init <contract.json> [state.json]
node tools/looper/looper.mjs record <state.json> <iteration.json>
node tools/looper/looper.mjs status <state.json>
```
Define `goal`, `inputContract`, `outputContract`, `successCriteria`, `tools` and a bounded `iterationPolicy`. Record actual input/output, observations, tools, evidence and criterion results. Completion requires evidence for every required criterion. Two identical failures require research before another iteration; they do not automatically terminate the loop.

## React / TypeScript verification
- Environment manifest: `tools/react-typescript-fullstack/environment.json`.
- Pinned tools and lockfile: `tools/react-typescript-fullstack/package.json`, `package-lock.json`.
- Run target install/build/tests using `runner/react-project.py`.
- Run static checks using `node tools/react-typescript-fullstack/scripts/quality-check-flat.mjs`.
- Run rendered browser inspection using `node tools/react-typescript-fullstack/scripts/inspect-browser.mjs` against a live `TARGET_BASE_URL`.
- Manual GitHub workflow: `.github/workflows/inspect-react.yml`; it accepts a public repository, ref and project path.
- Browser evidence includes screenshot, DOM text, console/page errors, failed requests, HTTP errors, Playwright trace and axe accessibility findings.

## Safety and verification
- Repository code is canonical over stale documentation.
- Target code is untrusted. The public inspection workflow uses read-only permissions, does not persist checkout credentials and passes no secrets to target code.
- Require approval for destructive, irreversible, costly or externally publishing actions.
- Never claim success from an attempted action. Use tests, builds, browser evidence, API results or independent verification.
