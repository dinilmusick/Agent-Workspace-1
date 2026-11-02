---
name: "Universal Task Router"
slug: universal-task-router
version: 1.3.2
source: Supabase Skills Database
sourceId: 28
status: active
---

# Universal Task Router

Top-level classifier for every incoming user message. Separate ordinary conversation, bounded one-step requests and actionable goals. Route actionable goals through the smallest sufficient skills and tools.

## 1. Conversation gate

- **Conversation:** greetings, acknowledgements, opinions, explanations, simple factual questions, casual discussion and ordinary follow-ups. Respond directly. Do not load skills just because the topic resembles one.
- **Direct one-step request:** a bounded request that can be completed in one response or one straightforward action. Complete directly or invoke one specialist only when it materially improves correctness. Do not create an artificial goal graph.
- **Actionable goal:** planning, multiple dependent actions, coordination, research, tool use, persistent changes, repeated practice or verification. Continue through the routing pipeline.

The user's explicit requested mode wins. If they ask for implementation, act rather than merely describing a plan.

## 2. Goal interpretation

Preserve intended outcome, scope, constraints, preferences, permissions, deadline and prior decisions. Derive observable success criteria. Use Prompt Map when the goal is multi-stage, ambiguous, cross-domain or dependency-heavy. Ask one targeted question only when an ambiguity materially changes the outcome; otherwise infer conservatively.

## 3. Loop routing

For actionable goals, inspect and load Loop Generator when repeated action/observation/diagnosis/verification is needed. A multi-task goal is itself a loop, and every task is also its own loop. These are separate persisted loops, not one synthetic task tree root.

The goal loop coordinates task loops and evaluates overall criteria. Task loops own task-specific execution, parameters, criteria and evidence. Use bounded iteration budgets. Stop on verified success, cancellation, safety/permission boundary, genuine blocker or budget exhaustion.

## 4. Domain routing

Select the narrowest active, published router or specialist:
- Software engineering / coding → Coding Router, then its specialist skills.
- Personal development, habits, values, learning goals or effectiveness → Personal Growth Router.
- Interpersonal communication, relationships, conflict, boundaries or repair → Personal Growth Router, then Relational Skills.
- Exercise, strength, conditioning, mobility or endurance → Fitness Coaching.
- Cooking, culinary technique, food science or meal preparation → Cooking and Culinary Skills.
- Other domains → inspect active skill categories and choose the closest specialist. If none exists, use available tools/research and report the capability gap.

## 5. Recursive skill nesting

Treat skill routing as a graph with arbitrary practical nesting depth:
- Inspect each selected skill's instructions, dependencies, capabilities and triggers before delegation.
- Track visited skill IDs/slugs and detect cycles.
- Load the smallest sufficient skill set, with one primary owner and bounded supporting skills.
- Required dependencies must be available; optional/recommended dependencies are loaded only when relevant.
- Stop descending when a concrete specialist owns the work. Preserve the parent-to-child handoff context.

## 6. Canonical persistent-goal workflow

For an agreed actionable goal requiring persistent progress, multiple tasks or independent ChatGPT conversations, load Task Ledger and Loop Generator.

### Goal identity
- `goals.name` is the descriptive title shown to the user.
- `goals.goal_key` is the stable readable identifier generated from the title.
- `goals.tags` is the searchable classification set.
- UUIDs are internal relational keys; never present them as the goal's identity.

### Create
1. Discuss and define the desired end state, context, constraints and acceptance criteria.
2. Generate a goal-level Loop Generator contract.
3. Decompose into direct top-level task definitions. Every task and nested task has its own complete loop contract, acceptance criteria, verification plan and task-specific parameter contract where applicable.
4. Call `goal_ledger_create_hierarchical` with title, tags, goal loop and task definitions. Do not call legacy `goal_ledger_create_with_tasks` for new goals; do not create a synthetic root task.
5. Add dependencies, inspect ready leaf-task parallelism and recommend the number of worker chats. The user manually opens those ChatGPT conversations.

### Resume from a new chat
When asked to continue, finish or resume an unfinished goal:
1. Call `goal_ledger_list_unfinished` immediately.
2. If exactly one unfinished goal exists, load it. If multiple exist, show title, readable key, tags and status, then ask the user to choose.
3. If the selected goal is blocked, resume it, report its blocker and do not claim a task until it is unblocked.
4. Call `goal_ledger_resume_by_key` and load complete goal/task context, dependencies, events, goal iterations and task iterations.
5. Tell the user **Loaded goal: <title>**. If asked which goal is loaded, answer with the title, not the UUID.
6. Only after selection and resume, claim one eligible task with `goal_ledger_claim_task_by_key`.

### Execution and completion
- Each worker chat uses a unique agent ID and session ID, claims exactly one task, executes its persisted loop, records iterations/evidence and submits the result.
- Workers do not self-verify. An independent verifier checks every result.
- Record goal-level cycles with `goal_ledger_record_loop_iteration`.
- A goal loop may pass only after all descendant tasks are independently verified, all goal acceptance criteria are satisfied and non-empty evidence is recorded.
- Finalize through `goal_ledger_finalize_by_key`. The database is canonical; recover from Supabase rather than chat history.

## 7. Task parameters

Use task `parameters` for task-specific configuration, `parameter_contract.required` for mandatory values, and `parameter_contract.properties` for JSON types and optional enum constraints. Workers submit fulfilled values in `result_in.parameter_values`. The database rejects completion if required values are missing or invalid.

## 8. GitHub compute workspace

When an agent needs an actual computation, program, parser, simulation, test or generated artifact, use `.github/workflows/agent-compute.yml` where an authorized workflow-dispatch capability is available. Supported runtimes: Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell.

The workflow runs on an ephemeral GitHub-hosted runner with read-only repository permission, no persisted checkout credentials, no application secrets and a bounded execution timeout. It returns an artifact. It is finite compute, not a persistent machine and does not spawn ChatGPT conversations. If the connected GitHub tools cannot dispatch workflows, state the limitation and use an authorized Actions UI/API path; never claim execution without a real run.

## 9. Execution handoff and output

Pass each skill a compact handoff containing goal, outcome, domain, scope, constraints, permissions, criteria, relevant context, prior work, tools, dependencies and evidence requirements. Verify at the layer where outcomes are observable.

For routed tasks, retain classification, selected skill path, loop activation decision, acceptance criteria, execution order and unresolved capability gaps. Keep ordinary responses concise; do not expose internal routing mechanics unless asked.

## 10. System boundaries

- Supabase is persistent storage and transactional coordination only. Use PostgreSQL RPCs for atomic claims, leases, iteration append, submission, verification and guarded finalization.
- Do not use Supabase Edge Functions for agent execution.
- GitHub Actions is finite CI/compute, not ChatGPT-agent orchestration.
- Never expose service-role credentials or secrets in prompts, task records, source files, logs or artifacts.
