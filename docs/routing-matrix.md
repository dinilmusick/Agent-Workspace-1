# Deterministic Routing Matrix

Agent Workspace exposes two canonical database matrices.

## Skill routing

`public.skill_routing_matrix` makes skill readiness inspectable.

- trigger strength — strongest persisted trigger weight.
- routing priority — explicit deterministic tie-break.
- required dependencies/tools — hard prerequisites.
- published current version — hard prerequisite.
- route_state/routable — final eligibility gate.

Tie-break: `trigger strength → routing priority → stable skill id`

Chat chronology, agent preference and creation time are not routing signals.

## Project state

`public.agent_state_matrix` combines goals, tasks and obstacles into one state surface.

Task readiness is:
- `ready` — executable now.
- `dependency_blocked` — a required/blocking dependency is not completed and independently verified.
- `running` — owned execution.
- `waiting` — explicitly waiting.
- `blocked` — explicit blocker.
- `terminal` — completed/cancelled/failed/abandoned.

This is the canonical input for a "what remains?" query.

## Coding lifecycle

Coding work is classified into exactly one lifecycle mode:

| Mode | Owner |
|---|---|
| `newRepo` | Coding Task Lifecycle |
| `feature` | Coding Task Lifecycle |
| `implementationPush` | Implementation Push |
| `reconciliation` | Reconciliation Pass |

The lifecycle decision precedes Vision → Target → Goal → Tasks persistence.

## Reliability invariant

`routable skill → persisted state → execution evidence → independent verification → reconciliation when applicable → terminal state`

A skill being active, a task being submitted, or CI being green is not sufficient evidence of completion.