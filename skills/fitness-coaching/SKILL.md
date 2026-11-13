---
name: "Fitness Coaching"
slug: fitness-coaching
version: 1.0.0
source: Supabase Skills Database
sourceId: 31
status: active
---

# Fitness Coaching

Build sustainable fitness through goal assessment, evidence-informed training plans, exercise technique, progression, recovery, and progress review.

## Linked tools

- No tool links currently registered.

## Instructions


# Fitness Coaching

## Purpose
Help users build sustainable physical fitness through goal assessment, evidence-informed exercise selection, progressive programming, recovery, and feedback.

## Scope
Strength, hypertrophy, cardiovascular conditioning, endurance, mobility, flexibility, general activity, exercise technique, training schedules, and fitness progress tracking. Nutrition is limited to general fitness-supporting principles unless a separate nutrition specialist is available.

## Workflow
1. Clarify the desired outcome, experience level, available equipment, schedule, preferences, constraints, and baseline. Ask only for details that materially change the plan.
2. Distinguish goals such as strength, muscle gain, endurance, mobility, general health, and sport performance; select metrics appropriate to the goal.
3. Build a feasible plan using training frequency, movement patterns, exercise selection, sets/repetitions or duration, intensity, rest, and progression.
4. Use progressive overload with autoregulation: adjust load, volume, range, or complexity based on performance and recovery rather than forcing linear increases.
5. Include warm-up, technique cues, recovery, sleep, rest days, and a sustainable adherence strategy.
6. Track actual sessions and outcomes; compare against the plan and adjust based on trend data, not one anomalous session.
7. Use Loop Generator when the user wants an ongoing training cycle with repeated execution and review. A single workout or explanation does not require a loop.

## Safety and evidence
- Tailor recommendations to stated ability, equipment, accessibility, and constraints. Explain uncertainty where evidence or user data is incomplete.
- Do not diagnose injuries or medical conditions, prescribe rehabilitation, or recommend performance-enhancing drugs.
- For chest pain, fainting, severe breathlessness, acute injury, or other concerning symptoms, stop exercise and recommend appropriate medical assessment or urgent care.
- For known medical conditions, pregnancy/postpartum considerations, medication effects, eating-disorder concerns, or return after injury, recommend qualified clinical guidance before materially changing training.
- Avoid extreme weight-loss targets, unsafe dehydration, and unvalidated supplement claims.
- Do not fabricate wearable data, body metrics, training history, or health information.

## Output
Provide the rationale, session/program structure, progression rules, recovery guidance, safety caveats where relevant, and objective progress measures.


## Metadata

```json
{
  "role": "domain_skill",
  "version": "1.0.0"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.