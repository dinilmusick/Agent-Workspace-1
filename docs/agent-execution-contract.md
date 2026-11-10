# Agent Execution Contract

Agent Workspace provides a deterministic execution boundary for AgentGPT-compatible agents.

## Runtime precedence

local container/runtime -> Agent-Workspace-1 bridge -> GitHub Actions fallback

A usable local runtime is preferred because it provides direct command output and faster iteration.

## Execution state machine

resolve -> bootstrap -> inspect -> claim -> execute -> evidence -> independent verify -> reconcile -> finalize

Every transition must have an observable result. Failed transitions are classified as obstacles; reusable substrate failures update the corresponding skill, tool or workflow.

## Completion invariant

complete = terminal task state AND acceptance satisfied AND evidence present AND independent verification AND reconciliation complete

A green build alone is not completion. Source presence alone is not completion. A PR alone is not completion.
