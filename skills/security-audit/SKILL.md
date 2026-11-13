---
name: "Application Security Audit"
slug: security-audit
version: 1.0.0
source: Supabase Skills Database
sourceId: 8
status: active
---

# Application Security Audit

Audit application code and infrastructure for exploitable vulnerabilities, unsafe trust boundaries, and security regressions.

## Linked tools

- No tool links currently registered.

## Instructions

# Application Security Audit

1. Define scope, assets, trust boundaries, attacker capabilities, and security objectives.
2. Trace authentication and authorization independently. Identify object-level access checks and privilege transitions.
3. Inspect input handling, output encoding, injection surfaces, file access, deserialization, SSRF, redirects, CORS, and request forgery.
4. Inspect secrets, tokens, logs, environment configuration, dependency versions, supply-chain integrity, and exposed debug endpoints.
5. Review data isolation, tenant boundaries, database grants, RLS, storage policies, and privileged functions.
6. Assess rate limiting, abuse controls, denial-of-service exposure, and resource exhaustion.
7. Validate findings with safe, scoped tests. Distinguish confirmed vulnerabilities from theoretical concerns.
8. Rank by exploitability and impact. Provide affected path, preconditions, evidence, severity, and remediation.
9. Implement authorized fixes and add regression tests. Re-test the exploit path.
10. Report residual risk and any area that could not be assessed.

Do not perform destructive exploitation, access unrelated data, or test third-party systems outside authorized scope. Never print discovered secrets.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "cloudflare/security-audit-skill"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.