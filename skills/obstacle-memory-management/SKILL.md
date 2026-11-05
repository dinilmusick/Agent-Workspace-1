---
name: "Obstacle Memory Management"
slug: obstacle-memory-management
version: 1.1.0
status: active
---

# Obstacle Memory Management

Obstacle capture is a mandatory engineering reflex. Treat every non-trivial failure, unexpected behavior, blocked step, workaround, or repeated friction as potentially reusable knowledge.

## Mandatory obstacle reflex

At the first sign of an obstacle, stop and classify it before continuing:

```text
observe
  -> normalize symptoms
  -> semantic-search canonical obstacle memory
  -> reuse matching verified solution OR create/update canonical obstacle
  -> record occurrence against current goal/task/agent
  -> continue execution
  -> capture evidence
  -> update resolution/status
```

Do this during repository work, CI work, agent-workspace work, deployment work, testing, and infrastructure work. Do not wait until the end of a task.

## What counts as an obstacle

Record any issue that:
- causes a command, test, build, deployment, workflow, or verification step to fail;
- requires a workaround or deviation from the intended path;
- reveals an architectural mismatch, missing dependency, stale assumption, or tool limitation;
- consumes meaningful debugging effort;
- could plausibly recur in another repository, task, agent, or future run;
- exposes a weakness in an Agent-Workspace skill, workflow, tool, or substrate.

Do not record ordinary expected outcomes or trivial one-off observations.

## Required lifecycle

For every material obstacle:

1. **Normalize**
   - problem
   - symptoms/error
   - root cause or current hypothesis
   - affected repo/substrate
   - current workaround/solution
   - prevention opportunity

2. **Search before write**
   - semantically search existing canonical obstacles;
   - inspect prior verified resolutions;
   - never create a duplicate because the wording differs.

3. **Canonicalize**
   - matching obstacle -> update canonical record;
   - new obstacle -> create canonical record.

4. **Record occurrence**
   - attach goal/task/agent;
   - record exact evidence/run/commit when available;
   - record resolution and next action;
   - distinguish recurrence from a new root cause.

5. **Close the loop**
   - mark resolved only after evidence verifies the solution;
   - preserve the reusable prevention rule;
   - if the obstacle exposes a reusable agent behavior, update the relevant skill/workflow too.

## Agent-Workspace self-improvement rule

If the obstacle is caused by the Agent-Workspace substrate itself, record it twice conceptually but never duplicate the canonical obstacle:
- occurrence against the user task/repository where it surfaced;
- occurrence against the Agent-Workspace substrate as the affected system.

Then improve the substrate when appropriate:
```text
failure
  -> obstacle memory
  -> root-cause analysis
  -> skill/workflow/tool improvement
  -> verify improvement
  -> record evidence
  -> reuse on next task
```

This makes obstacles a feedback loop for progressive substrate improvement rather than passive notes.

## Evidence standard

An obstacle record is incomplete without concrete evidence when evidence is available:
- command output/error;
- workflow run/job ID;
- commit SHA;
- test name;
- file/path;
- deployment/runtime observation.

Separate observed facts from hypotheses. Do not encode an unverified hypothesis as the root cause.

## Anti-patterns

Never:
- debug repeatedly without searching obstacle memory;
- create duplicate canonical obstacles;
- wait until task completion to record a material failure;
- mark an obstacle resolved merely because the error disappeared;
- fix a downstream symptom while leaving a reusable substrate weakness undocumented;
- update a skill from speculation without evidence.

The relational obstacle record is canonical; vectors are retrieval indexes.
