---
name: "Backend and API Engineering"
slug: backend-api-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 24
status: active
---

# Backend and API Engineering

Design and implement robust service boundaries, APIs, validation, authorization, error semantics, and distributed workflows.

## Linked tools

- No tool links currently registered.

## Instructions

# Backend and API Engineering

1. Trace the existing service facade, routes, handlers, domain logic, persistence, and external adapters.
2. Define the API contract: method, path, request/response schema, validation, errors, idempotency, pagination, and versioning.
3. Enforce authorization at the server boundary. Never rely on frontend visibility as access control.
4. Separate transport concerns from domain behavior. Keep domain invariants in the owning service/module.
5. Handle timeouts, retries, cancellation, duplicate delivery, partial failure, and rate limits where relevant.
6. Validate untrusted input and return stable, non-sensitive error responses with useful internal diagnostics.
7. Add contract and integration tests for success, invalid input, unauthorized access, and downstream failure.
8. Verify with real requests and inspect logs and persisted effects.
9. Document compatibility and operational implications.

Never expose credentials, internal stack traces, or privileged service operations through public endpoints.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "addyosmani/agent-skills"
}
```
