# Looper

A dependency-free, deterministic loop controller for agents. The agent plans and performs work; Looper persists iteration inputs/outputs and enforces evidence-gated completion, bounded retries, and terminal states.

## Contract

```json
{
  "goal": "Fix the application and verify it in a real browser",
  "inputContract": { "type": "object", "required": ["repository", "ref"] },
  "outputContract": { "type": "object", "required": ["changes", "verification"] },
  "initialInput": { "repository": "owner/repo", "ref": "main" },
  "successCriteria": [
    { "id": "build", "description": "Production build succeeds", "required": true },
    { "id": "browser", "description": "Critical route renders without runtime errors", "required": true }
  ],
  "tools": ["GitHub", "Playwright"],
  "iterationPolicy": { "maxIterations": 12, "repeatedFailureThreshold": 2 }
}
```

## Commands

```bash
node tools/looper/looper.mjs init tasks/example.loop.json results/example.state.json
node tools/looper/looper.mjs record results/example.state.json results/iteration-1.json
node tools/looper/looper.mjs status results/example.state.json
```

Each iteration result records the actual `input`, `output`, `observation`, `toolsUsed`, `evidence`, `criterionResults`, and `nextAction`.

```json
{
  "verdict": "continue",
  "input": { "repository": "owner/repo", "ref": "main" },
  "output": { "changes": ["src/App.tsx"], "verification": { "build": "passed" } },
  "observation": "Build passes; browser reports a failed API request.",
  "criterionResults": [
    { "criterionId": "build", "status": "satisfied", "evidence": ["actions://run/123"] },
    { "criterionId": "browser", "status": "unsatisfied", "evidence": ["playwright://trace/123"] }
  ],
  "toolsUsed": ["GitHub Actions", "Playwright"],
  "evidence": ["actions://run/123", "playwright://trace/123"],
  "failureKey": "api-base-url",
  "nextAction": "Trace the failed request and correct the base URL."
}
```

## State transitions

- `ready`: initialized; no iteration has been recorded.
- `continue`: more work is required.
- `research_required`: the same failure occurred twice; research the exact error before another attempt. This is not terminal.
- `completed`: every required criterion is explicitly marked satisfied and has evidence.
- `blocked`: a real external action, permission, or human decision is required.
- `cancelled`: explicitly cancelled.
- `max_iterations`: the configured iteration budget was exhausted.

A `pass` verdict cannot complete the loop unless every required criterion has evidence. A failed iteration is recorded and can be corrected; it does not immediately terminate the loop. The default iteration budget is 8 and the maximum is 100.

## Design boundary and shared state

Looper is the deterministic local controller, not an LLM, test runner, or evidence validator. The Loop Generator skill chooses tools and performs the work; tools produce evidence; the agent evaluates evidence and submits criterion results. For multi-agent work, Task Ledger remains the shared Supabase source of truth for task claims, nested tasks, iterations, results, and independent verification. Persist the same iteration input/output/evidence in Task Ledger when the loop belongs to a delegated task.

The script never executes model-generated shell strings, never assumes a tool exists, and stores no credentials.
