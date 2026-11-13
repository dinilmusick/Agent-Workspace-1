# Looper

A dependency-free, deterministic loop controller for agents. The agent plans and performs work; Looper persists iteration inputs/outputs and enforces evidence-gated completion, bounded retries, and terminal states.

## Machine-verifiable completion predicates

Bounded Task checkpoints are no longer completed by agent judgment. Each checkpoint references an immutable `(predicate_key, version)` stored in the Supabase completion predicate registry.

```text
agent performs work
      ↓
agent submits evidence/input
      ↓
predicate engine evaluates registered predicate
      ↓
true + evidence → checkpoint succeeds
false            → checkpoint remains incomplete/failed
      ↓
all checkpoints succeed → task may complete
      ↓
all direct tasks complete → goal may complete
```

Predicate types: `builtin`, `cel`, and `script`. CEL uses `@marcbachmann/cel-js`; script predicates require explicitly registered application handlers. Arbitrary model-generated code is never executed.

Every predicate execution records the predicate version, inputs, result, pass/fail verdict, executor identity, fencing token, and evidence. Predicate definitions are immutable; changed definitions require a new version.

### Task definition binding

A bounded task may provide predicates through its completion parameters:

```json
{"completion_parameters":[{"id":"build","description":"Production build succeeds","predicate":{"key":"repo.build_passes","version":1}}]}
```

Infrastructure-generated checkpoints use `builtin.evidence_present@1` only as a compatibility fallback. Production workflows should replace this with a predicate that actually verifies the requested outcome.

## State transitions

- `ready`: initialized; no iteration has been recorded.
- `continue`: more work is required.
- `research_required`: the same failure occurred twice; research the exact error before another attempt.
- `completed`: every required criterion is explicitly verified.
- `blocked`: an external action, permission, or human decision is required.
- `cancelled`: explicitly cancelled.
- `max_iterations`: the configured iteration budget was exhausted.

The existing four-task/four-checkpoint database bounds remain authoritative.

## Design boundary and shared state

Looper is the deterministic local controller, not an LLM, test runner, or arbitrary code sandbox. The completion predicate engine is the verification boundary: tools produce evidence; registered predicates determine whether a checkpoint is actually complete. Task Ledger remains the shared Supabase source of truth for delegated work.

The runtime never executes model-generated shell strings, never treats an agent's completion claim as authoritative, and stores no credentials.
