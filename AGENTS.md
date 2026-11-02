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
- Supabase Edge Functions are not used. Browser-chat agents use the connected Supabase PostgreSQL tools directly; the optional CLI runner uses Auth + PostgREST + RPC directly.
- Use runner/task-ledger.mjs for optional CLI/runtime API calls; configure SUPABASE_URL, SUPABASE_ANON_KEY, and a dedicated agent's SUPABASE_AGENT_JWT.
- Manually opened ChatGPT chats do not need separate Supabase Auth users; each supplies a unique agent_id and session_id. The optional CLI/runtime path requires an Auth user and enabled public.agent_registry row. Never expose the service-role key.
- Orchestrators create task trees; workers claim tasks using leases; every claim-bound write requires the returned claim token; verifier workers inspect pending results and iteration evidence, independently accept/reject results, and finalize ancestors only after all children are verified.
- Worker entrypoints: `runner/agent-worker.mjs` and `runner/verifier-worker.mjs`; both require a dedicated registered Supabase Auth identity and a runtime adapter contract.
- Follow `docs/task-ledger-integration.md` for provisioning and command examples.

## ChatGPT conversation workers and persistent goals
- Browser conversations are the workers. The user manually opens each chat; GitHub Actions never launches ChatGPT chats.
- Goal `name` is the descriptive title; `goal_key` is the readable stable identifier; UUID is internal only. Goals also have searchable tags.
- A goal is its own persisted Loop Generator loop (`goal_loop_definition`, `goal_loop_state`, `goal_iterations`). Every task, including nested parents, is a separate loop (`loop_definition`, `task_iterations`).
- Top-level tasks are direct children of the goal. Do not create a synthetic root task.
- Create new goals with `goal_ledger_create_hierarchical`, including a goal loop, tags and an array of top-level task definitions. Each task requires its own loop, acceptance criteria and optional `parameter_contract`.
- When a new chat is asked to continue an unfinished goal, call `goal_ledger_list_unfinished` first. If exactly one exists, resume it; if several exist, show titles/keys/tags/status and ask which to continue. Load with `goal_ledger_resume_by_key` and tell the user `Loaded goal: <title>` before claiming a task.
- Worker chats claim one task by readable key with `goal_ledger_claim_task_by_key`; load all context from Supabase, never from another chat's history.
- Persist goal iterations with `goal_ledger_record_loop_iteration` and task iterations with `task_ledger_record_loop_iteration`. A goal cannot pass until all descendants are independently verified and goal criteria have evidence.
- Task `parameter_contract.required` and `properties` define required values, types and enums. Workers return values through `result_in.parameter_values`; database validation blocks incomplete task completion.
- Use `goal_ledger_resume_by_key` to recover complete state and `goal_ledger_list_unfinished` to discover resumable goals.
- Supabase PostgreSQL is persistence and atomic coordination. The ChatGPT browser protocol uses the connected Supabase tools directly; do not route it through Supabase Edge Functions.
- GitHub Actions remains for CI and finite repository jobs, not ChatGPT conversation creation or always-on orchestration.
- See `docs/chat-agent-workflow.md` for exact orchestrator and worker prompts.

## GitHub compute workspace
- Use `.github/workflows/agent-compute.yml` for finite arbitrary code execution when an actual computation is required.
- Supported runtimes: Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell.
- Source must be in the selected repository revision. The ephemeral GitHub-hosted runner has read-only repository permissions, checkout credentials are not persisted, and no application secrets are passed to executed code. Execution is bounded to 1,200 seconds and returns an artifact.
- Do not treat GitHub Actions as a persistent machine or as a mechanism to spawn ChatGPT chats. To invoke from a ChatGPT conversation when workflow_dispatch is unavailable, create a GitHub issue with title `[agent-compute] <goal-key> <runtime>` and a JSON body containing `ref`, `runtime`, `source_file`, `arguments` (string array) and `timeout_seconds`. The issue trigger accepts only repository owners, members and collaborators. Track the issue's Actions run and retrieve its artifact. Do not claim execution without a real completed run.

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
