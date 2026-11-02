---
name: "Browser QA and Runtime Inspection"
slug: browser-qa
version: 1.0.0
source: Supabase Skills Database
sourceId: 10
status: active
---

# Browser QA and Runtime Inspection

Verify real browser behavior and rendered output using browser automation, console/network capture, and reproducible interaction checks.

## Linked tools

- No tool links currently registered.

## Instructions

# Browser QA and Runtime Inspection

1. Identify the deployed or local URL, target routes, user state, viewport, and expected browser behavior.
2. Start the application using the repository's documented command and wait for a confirmed ready state.
3. Use Playwright or the available browser automation tool to navigate actual routes and exercise realistic user flows.
4. Capture console errors and warnings, page errors, failed requests, response status codes, and relevant network payload metadata without exposing secrets.
5. Inspect the rendered DOM, accessibility tree, screenshots, layout dimensions, overflow, responsive behavior, and interactive states.
6. Compare observed output with requirements and design references. Trace mismatches back to source and runtime conditions.
7. Reproduce failures, fix root causes, and rerun the same browser scenario.
8. Save reproducible evidence: route, viewport, steps, console/network findings, screenshots, and pass/fail criteria.
9. Report untested routes and environmental limitations.

Never infer rendered behavior from source code alone. Do not report a browser test as passed if it only compiled or loaded the page.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "vercel-labs/agent-skills"
}
```
