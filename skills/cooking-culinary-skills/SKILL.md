---
name: "Cooking and Culinary Skills"
slug: cooking-culinary-skills
version: 1.0.0
source: Supabase Skills Database
sourceId: 32
status: active
---

# Cooking and Culinary Skills

Teach and apply cooking through technique, food science, recipe development, flavor design, ingredient substitution, meal preparation, and food safety.

## Linked tools

- No tool links currently registered.

## Instructions


# Cooking and Culinary Skills

## Purpose
Teach, plan, troubleshoot, and improve cooking through practical technique, food science, recipe development, flavor reasoning, and safe kitchen practice.

## Scope
Recipes, ingredient substitutions, cooking methods, knife skills, heat control, seasoning, sauces, baking fundamentals, meal preparation, cuisine exploration, menu planning, equipment use, and culinary skill development.

## Workflow
1. Identify the requested mode: explain, cook a dish, adapt a recipe, troubleshoot a failure, plan meals, or deliberately learn a technique.
2. Establish relevant constraints: ingredients, equipment, servings, time, budget, skill level, cuisine, dietary preferences, and food allergies. Do not force an intake questionnaire; ask only for critical missing details.
3. For recipes, provide quantities, preparation, ordered steps, heat level, timing ranges, sensory cues, and doneness checks. Prefer observable cues over blind timers.
4. Explain the mechanism when useful: heat transfer, protein denaturation, starch gelatinization, gluten development, emulsification, Maillard browning, caramelization, fermentation, and acid/salt/fat balance.
5. When troubleshooting, identify the likely failure mechanism, distinguish evidence from hypotheses, and suggest the smallest corrective action.
6. For substitutions, explain functional equivalence and trade-offs in moisture, structure, acidity, fat, sweetness, flavor, and cooking time.
7. For skill development, design deliberate-practice exercises with a feedback criterion; use Loop Generator only when repeated practice and review are part of the user's goal.

## Food safety
- Treat allergies and cross-contact as hard constraints. Never assume a substitution is allergen-safe without checking ingredients and preparation.
- Separate raw and ready-to-eat foods; use safe storage, thawing, hygiene, and validated internal-temperature guidance appropriate to the food.
- Do not rely on smell or appearance alone to determine microbiological safety.
- For preservation, fermentation, canning, or high-risk foods, use tested procedures and authoritative food-safety guidance; do not improvise unsafe processing parameters.
- Distinguish culinary quality advice from food-safety requirements.

## Output
Give an actionable recipe or technique, explain critical cues and failure points, identify substitutions and trade-offs, and state relevant food-safety constraints.


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