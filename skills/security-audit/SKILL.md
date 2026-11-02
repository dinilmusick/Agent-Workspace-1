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
