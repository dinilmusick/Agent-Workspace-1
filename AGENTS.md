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
7. For explicit implementation-push requests, route to the dedicated Implementation Push skill and require the full completion/verification loop.

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

- Call the goal overview through the trusted Supabase database connector/service-role context only. The RPC is intentionally not executable by anonymous or ordinary authenticated API roles because it exposes the single-owner workspace's complete goal/task graph; do not grant it publicly.
- At the start of every orchestration session, and whenever asked what goals remain, call `goal_ledger_overview(null)` and report the complete visible set of planning, ready, active and blocked goals with task counts, running agents, queued work, blockers and verification state. Do not limit discovery to one selected goal.
- Use `goal_ledger_resume_by_key` to load the selected goal's full persisted context before claiming work. The overview is discovery, not a claim; always use the atomic claim RPC.
- A running task is eligible for reassignment only when its heartbeat is at least 60 minutes old. Lease expiry alone must never bypass the one-hour inactivity threshold. New claims use a minimum 60-minute lease; reassignment must happen through the transactional claim RPC; never overwrite task ownership directly.
- Apply stale recovery consistently to the standard goal-key ChatGPT worker path and generic claim entry points. Recovery rotates claim tokens, increments attempts and appends a `lease_recovered` event with prior-worker evidence. Preserve all prior iterations and evidence.
- Never automatically reclaim tasks in `blocked` state, tasks under blocked/failed/cancelled/abandoned parents, or tasks whose blocking dependencies remain unverified. Respect max attempts.
- Worker heartbeats must renew leases during active work. A 60-minute stale threshold is crash recovery, not permission to ignore heartbeat duties.
- Recovery and goal discovery implementation details and the rollback-only integration test are documented in `docs/agent-recovery-and-goal-overview.md`.


- Goal `name` is the descriptive title; `goal_key` is the readable stable identifier; UUID is internal only. Goals have searchable tags.
- A goal is its own persisted Loop Generator loop (`goal_loop_definition`, `goal_loop_state`, `goal_iterations`). Every task, including nested parents, has a separate loop (`loop_definition`, `task_iterations`).
- Top-level tasks are direct children of the goal. Do not create a synthetic root task.
- Create goals with `goal_ledger_create_hierarchical`, including a goal loop, tags and top-level task definitions. Each task requires its own loop, acceptance criteria and optional `parameter_contract`.
- At the start of every actionable orchestration session, call `goal_ledger_overview(null)`. When asked what goals remain, show the complete overview of all planning, ready, active and blocked goals, including acceptance criteria, task counts, task owners, heartbeats, current steps, blockers and verification states. Do not report only the first matching goal.
- When asked to continue an unfinished goal, call `goal_ledger_list_unfinished`. If exactly one exists, resume it; if several exist, show titles/keys/tags/status and ask which to continue. Load with `goal_ledger_resume_by_key` and announce `Loaded goal: <title>` before claiming a task.
- Claim one available leaf task using `goal_ledger_claim_task_by_key`. Load all context from Supabase, never from another chat's history.
- A running task is reclaimable only after 60 minutes without a heartbeat; lease expiry alone does not permit reassignment. New claims and renewals use at least 60-minute leases. Reassignment must occur through the atomic claim RPC; never edit task ownership directly. The RPC rotates the claim token and records the previous worker in a `lease_recovered` event.
- Never auto-reclaim tasks in `blocked` state or tasks blocked by an unresolved parent/dependency. Preserve previous iterations, events, evidence and commit references when resuming.
- Persist goal iterations with `goal_ledger_record_loop_iteration` and task iterations with `task_ledger_record_loop_iteration`.
- Task `parameter_contract.required` and `properties` define required values, types and enums. Workers return values through `result_in.parameter_values`; database validation blocks incomplete completion.
- A goal cannot pass until all descendants are independently verified and goal criteria have evidence.


## New-chat goal discovery and task proposals

When a new conversation begins, or the user asks what remains / what goals need completion:
1. Call `goal_ledger_overview(null)` before proposing work. This is the global source of truth; never rely on chat history or a single remembered goal.
2. Summarize every planning, ready, active and blocked goal using its readable `goal_key`, status, task counts, active workers, heartbeat age, queued work, blockers and verification state. Identify tasks that are actually claimable separately from queued tasks blocked by dependencies.
3. Load the full context of a goal before recommending changes to it.
4. Compare the user's current request and the live goal/task tree. If a concrete, relevant piece of work is missing, propose it as a task instead of silently adding it.
5. Ask one explicit confirmation question: **“Should I add this as a task?”** Include its proposed title, scope, acceptance criteria, dependencies and readable task ID. Do not write the task until the user confirms.
6. On confirmation, create the task under the selected goal using the canonical task-tree creation RPC. Persist its loop contract, acceptance criteria, verification plan, required tools/capabilities and dependencies. Return the generated readable task ID and the parent goal key.
7. If no task is missing, say so. Do not manufacture tasks merely to appear proactive.

### Readable task IDs
- New task IDs are generated by the database from the task title: `task-<descriptive-kebab-case>-<8-hex-suffix>`.
- Use the exact returned `task_key` in discussion and handoffs. UUIDs remain internal database identifiers.
- Never invent an ID before persistence or promise that a proposed ID is reserved. Before confirmation, show it as a proposed slug only; after creation, report the canonical returned key.
- Existing legacy task keys remain valid; do not rewrite historical task identifiers.

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

## Private repository CI fallback

- Private repositories must not become blocked merely because native GitHub CI is unavailable, exhausted, or otherwise unsuitable.
- For private-repository CI/test verification, route through skills/private-repo-ci-workspace-runner/SKILL.md whenever native private CI cannot provide the required evidence.
- The fallback runner is Agent-Workspace-1 itself: update .agent/ci-request.json with { repository, ref, event, workflow, token_mode, request_id }, let .github/workflows/private-repo-ci.yml clone the private repository into the dedicated clones/ directory, validate workflow definitions, execute them through pinned act, collect run/test evidence, and always clean the clone.
- Prefer this fallback extensively for private-repository verification instead of stopping because GitHub-hosted private CI is unavailable or quota-limited.
- Use PRIVATE_REPO_TOKEN only for read-only cloning/verification. Never expose CODING_REPO_TOKEN or DEPLOYMENT_TOKEN to target workflow code. Write/deployment credentials remain Agent-Workspace-controlled.
- Prefer an explicit target workflow. Running all workflows is allowed only when the target repository is trusted and its workflows are safe for verification.
- Completion requires a real fallback run, target verification evidence, independent verification where applicable, and confirmed clone cleanup.

## GitHub-native development substrate

GitHub is a first-class execution substrate, not only a source-control API.

- If Supabase is unavailable, continue using GitHub as the source of repository truth and GitHub Actions as the execution/evidence layer.
- Use `github-development-workspace` for authorized repository edit/build/lint/typecheck/test workflows.
- Use `create-skipo-app.yml` to create a repository and scaffold it directly from canonical Skipo.
- Use `github-public-compute-matrix.yml` when cross-platform verification is useful.
- Use `private-repo-ci-workspace-runner` when private native CI is unavailable/exhausted/blocked.
- Prefer GitHub-hosted standard public runners for compute. Public-repository standard runner usage is free and unlimited; use the available Linux/Windows/macOS standard environments deliberately.
- Repository creation requires a coding credential with GitHub **Repository creation: write** permission.
- Agents with GitHub access should be able to complete the full repository lifecycle without Supabase: create → scaffold → code → lint → test → build → verify → commit/push → Actions evidence.
- For ULTRST/Skipo development, treat GitHub + Actions + canonical Skipo/GutTS/KrnlTS/FrnlTS/Kloks/Floks/Luth/Srkl/Loky repositories as the executable development substrate. Supabase is coordination state, not a prerequisite for coding.

## Implementation Push

An **implementation push** is a first-class coding execution mode, not merely a review. When the user explicitly asks for an implementation push (or equivalent), route to `skills/implementation-push/SKILL.md`.

The implementation-push agent must:
- re-analyze the **entire target codebase** with a fresh perspective, not just the latest diff;
- rediscover architecture, execution paths, interfaces, dependencies, data flow, runtime boundaries and tests;
- actively search for bugs, stubs, TODOs, placeholders, dead paths, fake behavior, missing error handling, incomplete contracts and systems that are implemented but not actually wired together;
- reproduce and diagnose findings, then implement the missing behavior and fix root causes rather than merely reporting them;
- rewire affected layers and verify actual runtime reachability;
- run verification from focused/unit checks through integration and end-to-end/browser/API/platform checks as applicable;
- loop through re-analysis → fix → verification until the implementation is complete, or every remaining gap has a concrete external blocker or explicit out-of-scope reason;
- record evidence and require independent verification before declaring completion.

A green build or test suite is not sufficient proof of an implementation push. Source presence is not proof of wiring, and analysis is not completion.


### Implementation Push PR rule
Every implementation push is a new dedicated branch and PR. The PR must have a descriptive name and enumerate exact stubs, bugs, incomplete features, wiring changes, removals, tests/E2E results, and remaining blockers. Multiple implementation-push PRs may run concurrently against the same repository; keep each push independently reviewable.

## Deterministic execution bootstrap

For any substantive repository task, establish the execution substrate before editing: use a usable local container/runtime first; clone Agent-Workspace-1 into that runtime; use its tools/scripts; attempt the target repository directly; if a private target cannot be cloned directly, use the Agent-Workspace-1 private-repository tooling and dedicated clones bridge. Discover and run all repository-defined build, test, typecheck, lint and custom build scripts that participate in the real build. Use GitHub Actions only when local execution is unavailable, insufficient for the target environment, or remote evidence is explicitly required. Capture command results as evidence and require independent verification before completion.

The canonical local preflight is `python tools/agent-bootstrap/bootstrap.py plan`; use `prepare` to establish the workspace and target checkout. Never place credentials in source, logs or task metadata.


## Persistent multi-agent coding execution

- Supabase is canonical for goals, non-coding task state, dependencies, leases and durable orchestration evidence. For coding execution, the GitHub Issue is the canonical task-state and communication record; Supabase stores the parent goal/task relationship and Issue/PR references rather than duplicating the full coding queue.
- Every independent coding task gets exactly one GitHub Issue and one dedicated PR/worker. The Issue must contain objective, acceptance criteria, dependencies, current implementation state, evidence, blocker/question, orchestrator response and resume point.
- Worker protocol: read the complete Issue before acting → execute → update the Issue whenever material state changes → create/update PR evidence → poll the Issue when blocked or waiting. Never leave a blocker only in chat.
- Blocked workers MUST write: status, completed work, current work, exact blocker, question for orchestrator, attempted resolution, relevant files/tests, and a deterministic resume point. Then they wait/poll for an orchestrator response; they do not silently abandon the task.
- Orchestrator protocol: continuously poll active Issues, linked PRs and CI; answer worker questions by editing/commenting on the Issue; preserve decisions in the Issue; keep the execution loop alive while actionable work exists.
- continue/proceed is a global resume signal, not a new task. Every worker re-reads its own Issue. A terminal worker performs no unrelated work; a resolved blocker resumes; an unresolved blocker remains waiting/polling; an active worker continues its existing task.
- Never require the user to identify which worker is blocked or completed. The orchestrator derives this from live Issues/PRs/CI. User intervention is reserved for genuine external decisions, permissions, platform limits or unrecoverable blockers.
- Reconciliation must inspect linked Issues as well as PRs, synchronize terminal state/evidence, and leave no coding task with lost execution context.
- Use skills/persistent-multi-agent-execution/SKILL.md as the primary multi-agent execution protocol and apply it to Implementation Push, Feature, New Repo and Reconciliation workflows.


## Goal prerequisite gates

- Model phase ordering with `public.goal_dependencies`; edge direction is dependent goal → prerequisite goal.
- Add `blocking` edges for true phase gates and `advisory` edges for context-only relationships.
- Use `goal_ledger_add_dependency(dependent_goal_key, prerequisite_goal_key, 'blocking'|'advisory', agent_id)` through the trusted Supabase service-role connector. Do not mutate the dependency table through public client roles.
- A blocking prerequisite must be completed and all its descendant tasks independently verified before a dependent goal can activate/complete or any dependent task can enter `running`. The database is the enforcement authority.
- Reject self-edges, duplicate edges, blocking cycles and cross-Vision dependencies. The database serializes graph writes to prevent concurrent cycle races.
- Add all phase edges before starting workers. Never launch a later phase merely because its tasks are queued; inspect the dependency gate and claimability.
- Advisory dependencies never block execution. Preserve parallelism among tasks/goals that do not have blocking paths between them.
- Regression coverage: `supabase/tests/task-ledger-goal-dependencies.integration.sql` (rollback-only fixtures).
