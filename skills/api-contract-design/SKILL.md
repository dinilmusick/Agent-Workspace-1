---
name: "API Contract and Integration Design"
slug: api-contract-design
version: 1.0.0
source: Supabase Skills Database
sourceId: 22
status: active
---

# API Contract and Integration Design

Design stable contracts and integrations between services, packages, clients, and external providers.

## Linked tools

- No tool links currently registered.

## Instructions

# API Contract and Integration Design

1. Identify producers, consumers, ownership, trust boundaries, and lifecycle of the contract.
2. Define names, types, required/optional fields, validation, defaults, errors, and compatibility rules.
3. Specify idempotency, ordering, pagination, retries, timeouts, and event delivery semantics where relevant.
4. Prefer explicit versioning and additive evolution. Identify breaking changes before implementation.
5. Generate or validate types from a canonical schema when possible.
6. Test producer and consumer behavior against the same contract, including malformed and older-version inputs.
7. Verify integration in the real deployment/runtime and document migration requirements.

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
