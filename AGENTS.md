# Agent Workspace instructions

## Canonical architecture

- **Supabase PostgreSQL** is the sole persistent goal/task ledger and coordination system.
- **ChatGPT conversations** are the reasoning agents. The user manually opens orchestrator and worker chats.
- **GitHub Actions Agent Compute Workspace** is the sole general-purpose finite code-execution environment.
- Use connected Supabase PostgreSQL tools directly for all goal/task operations. There is no Edge Function or repository-hosted CLI worker layer in the supported architecture.

## Entry routing

1. Treat ordinary conversation as conversation; do not invoke a skill automatically.
2. For an actionable goal, read `skills/universal-task-router/SKILL.md`.
3. Resolve current skill versions from `skills/current-versions.json` and Supabase `public.skills.current_version_id`.
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
- Do not infer tool availability from registration. Verify the connector, permissions and authentication before use.

## Workspace boundaries

- `workspaces/`: disposable target repositories and experiments. Never commit target application code here.
- `tools/`: permanent, version-controlled scripts, package manifests, lockfiles and tool adapters.
- `runner/`: helpers used by Agent Compute and project inspection workflows.
- Do not place credentials, private source or user secrets in this public repository.

## Goal and task invariants

- Goal `name` is the descriptive title; `goal_key` is the readable stable identifier; UUID is internal only. Goals have searchable tags.
- A goal is its own persisted Loop Generator loop (`goal_loop_definition`, `goal_loop_state`, `goal_iterations`). Every task, including nested parents, has a separate loop (`loop_definition`, `task_iterations`).
- Top-level tasks are direct children of the goal. Do not create a synthetic root task.
- Create goals with `goal_ledger_create_hierarchical`, including a goal loop, tags and top-level task definitions. Each task requires its own loop, acceptance criteria and optional `parameter_contract`.
- When asked to continue an unfinished goal, call `goal_ledger_list_unfinished`. If exactly one exists, resume it; if several exist, show titles/keys/tags/status and ask which to continue. Load with `goal_ledger_resume_by_key` and announce `Loaded goal: <title>` before claiming a task.
- Claim one available leaf task using `goal_ledger_claim_task_by_key`. Load all context from Supabase, never from another chat's history.
- Persist goal iterations with `goal_ledger_record_loop_iteration` and task iterations with `task_ledger_record_loop_iteration`.
- Task `parameter_contract.required` and `properties` define required values, types and enums. Workers return values through `result_in.parameter_values`; database validation blocks incomplete completion.
- A goal cannot pass until all descendants are independently verified and goal criteria have evidence.

## Identity and security boundary

The connected Supabase project currently has no Auth users. Browser chats use unique `agent_id` and `session_id` values within a single-owner project-scoped workspace when `auth.uid()` is null. A different chat may verify/finalize, but its agent ID must differ from task workers. This is not multi-tenant isolation. Before sharing with multiple human owners, provision Supabase Auth users and enforce owner-scoped JWT/RLS boundaries.

## GitHub compute

- Use `.github/workflows/agent-compute.yml` for finite arbitrary code execution.
- Supported runtimes: Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell.
- Source must exist in the selected repository revision. The ephemeral runner has read-only repository permissions, checkout credentials are not persisted, and no application secrets are passed to executed code. Timeout is capped at 1,200 seconds; outputs are returned as an artifact.
- When workflow_dispatch is unavailable, create an issue titled `[agent-compute] <goal-key> <runtime>` with a JSON body containing `ref`, `runtime`, `source_file`, `arguments` (string array) and `timeout_seconds`. Only repository owners, members and collaborators may invoke the issue route. Track the Actions run and retrieve its artifact.
- GitHub Actions is finite compute, not a persistent machine and not a mechanism to spawn ChatGPT chats.

## Looper

Use:
```bash
node tools/looper/looper.mjs init <contract.json> [state.json]
node tools/looper/looper.mjs record <state.json> <iteration.json>
node tools/looper/looper.mjs status <state.json>
```

Define `goal`, `inputContract`, `outputContract`, `successCriteria`, `tools` and a bounded `iterationPolicy`. Record actual inputs/outputs, observations, tools, evidence and criterion results. Completion requires evidence for every required criterion.

## React / TypeScript verification

- Environment manifest and pinned toolchain: `tools/react-typescript-fullstack/environment.json`, `package.json` and `package-lock.json`.
- Run target install/build/tests using `runner/react-project.py`.
- Run static checks using `node tools/react-typescript-fullstack/scripts/quality-check-flat.mjs`.
- Run rendered browser inspection using `node tools/react-typescript-fullstack/scripts/inspect-browser.mjs` against a live `TARGET_BASE_URL`.
- Manual workflow: `.github/workflows/inspect-react.yml`. It accepts a public repository, ref and project path.

## Safety and verification

- Repository code is canonical over stale documentation.
- Target code is untrusted. Workflows must use read-only permissions, avoid persisting checkout credentials and pass no secrets to target code.
- Require approval for destructive, irreversible, costly or externally publishing actions.
- Never claim success from an attempted action. Verify with tests, builds, browser evidence or database results.
