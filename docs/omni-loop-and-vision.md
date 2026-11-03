# Omni Loop + Vision Model

The Agentic Workspace uses one canonical behavioral abstraction for goals, tasks, and iterations.

## Omni Loop

```text
TARGET
  │
  ├── behavior inputs ──► TARGET ──► observed outputs
  │                         ▲
  │                         │
  └──────── EDIT ───────────┘
             │
             ▼
        next loop input
```

An **edit** is a bounded change to the constitution, structure, configuration, code, data, or internals of exactly one target. The edit is the loop input/change. The target's behavior after the edit is the loop output.

Every Omni Loop contains:

- exactly one `target`
- an `objective`
- one or more `edits`
- an input contract
- an output contract
- a transformation
- an observation method
- an evaluation
- a revision policy
- stop conditions
- bounded iteration policy

A goal is an Omni Loop whose output is judged against its declared `behavior_inputs` and `expected_outputs`.

A task is also an Omni Loop, but its target is immutable: a task must inherit exactly the target of its parent goal or parent task.

## Closed vocabularies

**Goal types:** `coding`, `learning`, `research`, `design`, `creative`, `operations`, `business`, `personal_development`, `maintenance`, `system`, `general`.

**Task types:** `implementation`, `investigation`, `research`, `design`, `learning`, `verification`, `documentation`, `maintenance`, `operations`, `review`, `general`.

**Target types:** `repository`, `person`, `application`, `service`, `database`, `workspace`, `document`, `organization`, `system`, `device`, `general`.

These vocabularies are defined in `schemas/ontology.ts` and enforced by the database for canonical Omni Loop creation.

## Goal anatomy

```text
Goal
├── type
├── target                         ← exactly one
├── behaviorInputs[]               ← inputs to target
├── expectedOutputs[]              ← observable target behavior
├── acceptanceCriteria[]
└── omniLoop
    ├── edits[]
    ├── inputContract
    ├── outputContract
    ├── observation
    ├── evaluation
    └── revisionPolicy
```

Goal completion means the target produces the expected outputs for the declared inputs and all persisted verification gates pass.

## Task anatomy

```text
Task
├── type
├── target = parent target       ← immutable constraint
├── acceptanceCriteria[]
└── omniLoop
```

Nested tasks may refine execution but may never retarget the work.

## Vision anatomy

A Vision is the planning container above goals:

```text
Vision
└── one target
    │
    ├── component target A
    │   ├── Goal A1
    │   │   └── Tasks...
    │   └── Goal A2
    │       └── Tasks...
    │
    └── component target B
        └── Goal B1
            └── Tasks...
```

The database stores the vision, component-target graph, goal links, and tldraw identifiers. The tldraw skill owns creation of the external board and its pages.

## tldraw contract

When creating a Vision:

1. Ask which tldraw workspace should contain the board.
2. Create one new board named after the Vision.
3. Create/identify the page named **Vision Overview**.
4. Represent each component target as a rectangle.
5. Put that target's goals beneath it.
6. Create one sub-page per component target.
7. Persist the board/workspace/page identifiers in Supabase.
8. Reflect goal/task status from Supabase onto the relevant target page.
9. Keep the visual board as a projection of Supabase state; Supabase remains the source of truth.
