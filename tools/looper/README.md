# Looper

A dependency-free, deterministic loop-state controller for agent workflows. The agent performs the work; Looper owns the persisted iteration contract and terminal-state decision.

## Contract

Create a JSON input:

```json
{
  "goal": "Fix the application and verify it in a real browser",
  "successCriteria": [
    { "id": "build", "description": "Production build succeeds" },
    { "id": "browser", "description": "Critical route renders without page or console errors" }
  ],
  "maxIterations": 8
}
```

Initialize state:

```bash
node tools/looper/looper.mjs init tasks/example.loop.json results/example.state.json
```

After each worker iteration, write an output JSON and record it:

```json
{
  "verdict": "continue",
  "summary": "Build passes; browser reports a missing API response.",
  "evidence": [{ "type": "test", "name": "build", "passed": true }],
  "satisfiedCriteria": ["build"],
  "nextAction": "Trace the failing API request and correct its base URL."
}
```

```bash
node tools/looper/looper.mjs record results/example.state.json results/iteration-1.json
node tools/looper/looper.mjs status results/example.state.json
```

## Verdict semantics

- `continue`: another bounded iteration is required.
- `pass`: completes only when every required criterion ID is present in `satisfiedCriteria`; otherwise remains open.
- `blocked`: terminal handoff requiring an external action or decision.
- `fail`: terminal failure; caller may explicitly start a new loop after diagnosis.
- `cancelled`: terminal cancellation.

Every state update records the iteration, verdict, summary, evidence, timestamp and next action. The controller caps iterations at 100 and defaults to 8. It never runs arbitrary commands or evaluates model-generated shell strings.

## Design boundary

Looper is the mechanical controller, not the reasoning agent or test runner. The Loop Generator skill plans, acts, observes and diagnoses; environment tools (for example Playwright) produce evidence; Looper persists state and enforces stop conditions. The caller must validate evidence before submitting a `pass` verdict.
