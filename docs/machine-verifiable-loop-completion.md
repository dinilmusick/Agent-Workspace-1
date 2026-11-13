# Machine-verifiable loop completion

## Contract

Bounded-v2 execution is:

Vision -> 1..N Goals -> 1..4 direct Tasks -> 1..4 Checkpoints.

A checkpoint is not completed because an agent says it succeeded. Each checkpoint must reference an immutable, versioned completion predicate.

agent performs work
      |
      v
evidence / inputs
      |
      v
completion predicate execution
      |
   +--+--+
   |     |
 false  true
   |     |
failed  succeeded
          |
          v
all checkpoint predicates true
          |
          v
       Task may complete

## Predicate types

### builtin

Use for deterministic checks that can be evaluated by the trusted substrate or a registered evaluator.

Example:

{
  "key": "repository.tests_pass",
  "kind": "builtin",
  "description": "Repository tests pass",
  "input_schema": {
    "type": "object",
    "required": ["exit_code"]
  },
  "definition": {
    "name": "exit_code_is_zero"
  }
}

### script

Use for checks that require finite code execution.

Example:

{
  "key": "repository.has_git_directory",
  "kind": "script",
  "description": "The cloned repository contains a Git directory",
  "input_schema": {
    "type": "object",
    "required": ["path"]
  },
  "definition": {
    "script_id": "repository.verify",
    "entrypoint": "has_git_directory"
  }
}

The script is not stored as mutable executable SQL. Its immutable registry record identifies the versioned script and entrypoint. Agent Workspace's existing finite-compute boundary runs the script and returns result/evidence. The completion RPC records that execution.

## Creating a bounded task

Each checkpoint must carry a predicate definition at creation time. The database trigger registers or reuses the immutable predicate and stores its predicate_id, predicate_version and predicate_hash.

Example task payload:

{
  "name": "Clone and verify repository",
  "actions": [
    { "description": "Clone the repository" }
  ],
  "completion_parameters": [
    {
      "id": "clone_verified",
      "description": "The repository is cloned and usable"
    }
  ],
  "checkpoints": [
    {
      "parameter_id": "clone_verified",
      "objective": "Clone and verify the repository",
      "status": "pending",
      "predicate": {
        "key": "repository.has_git_directory",
        "kind": "script",
        "description": "The cloned repository contains a Git directory",
        "input_schema": {
          "type": "object",
          "required": ["path"]
        },
        "definition": {
          "script_id": "repository.verify",
          "entrypoint": "has_git_directory"
        }
      }
    }
  ]
}

## Execution

After the registered script or evaluator runs, call:

select public.task_ledger_record_predicate_execution(
  '<task-id>',
  0,
  'repository.has_git_directory',
  1,
  '{"path":"/workspace/repo"}',
  '{"exists":true}',
  true,
  '["actions://run/123"]',
  '<executor-agent-id>',
  'actions://run/123'
);

The RPC verifies that the checkpoint predicate id/version/hash matches the immutable registry entry, appends an execution record, updates the checkpoint status/result/context/evidence, and advances current_checkpoint_index only on success.

A bounded-v2 task cannot transition to completed unless every checkpoint is succeeded and every checkpoint has a recorded predicate execution.

## Immutability

Predicate definitions cannot be updated or deleted. To change a predicate, register a new version. Checkpoints keep the exact predicate version and hash they were created with.

This prevents a running task from silently changing its definition of success.

## Agent boundary

The agent may:
- perform the requested work;
- provide execution inputs;
- collect evidence;
- request predicate execution.

The agent may not declare a checkpoint successful by changing its checkpoint status.

The completion engine is authoritative.

## Resume

A new agent only needs:
1. unfinished Goal;
2. selected Task;
3. current checkpoint index;
4. checkpoint predicate;
5. latest execution/evidence.

It does not need the previous conversation.

## Compute boundary

Supabase is the durable state and coordination substrate. It should not execute arbitrary agent-generated shell or code. PostgreSQL functions handle deterministic state transitions, while finite repository/test scripts belong in the existing ephemeral GitHub Actions compute boundary.

Supabase provides pg_jsonschema for JSON/JSONB contract validation, which can be used for stricter predicate input schemas. See the official Supabase documentation.

XState's guard model is a useful architectural reference for pure deterministic transition guards: guards determine whether a transition is allowed and should be synchronous and side-effect free.

Temporal is a useful durability and replay reference, but Agent Workspace deliberately does not introduce a second workflow authority.

## Design invariant

Task completion is now:

TaskComplete =
  every checkpoint predicate succeeds
  AND every checkpoint has a recorded execution
  AND existing result/verification requirements pass.

Agent-reported success is evidence, never the authority.
