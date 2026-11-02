# Supabase Skills integration contract

The connected Supabase project `Skills Database` contains a normalized skill catalogue: `skills`, `skill_versions`, `skill_tools`, and `skill_tool_links`. The workspace integration should be represented in that catalogue rather than hiding tool selection inside one monolithic instruction.

## Required skill instructions

For code execution, repository inspection, React/TypeScript builds, and browser verification, resolve and use these workspace capabilities:

| Capability | Permanent implementation | When to use |
|---|---|---|
| Public repository checkout | `runner/checkout-public-repository.py` | Stage a public target repository into the disposable workspace |
| React project preparation | `runner/react-project.py prepare` | Detect package manager, install locked dependencies, run available build and test scripts |
| React project startup | `runner/react-project.py start` | Start the app in the disposable workspace |
| Browser inspection | `tools/react-typescript-fullstack/scripts/inspect.mjs` | Inspect rendered page, console, page exceptions, network failures, HTTP errors, screenshot, DOM text and trace |
| Generic task execution | `runner/execute.py` | Execute a versioned argv task manifest |
| Result verification | `runner/verify.py` | Validate the machine-readable execution result |

## Agent execution sequence

1. Identify repository, ref and app package path.
2. Select an environment by language/framework; initially use `javascript.typescript.fullstack.react`.
3. Check out the target into `workspaces/target/`.
4. Run the environment's preparation and build/test steps.
5. Start the application and wait for readiness.
6. Run Playwright inspection against the live URL.
7. Retrieve the workflow artifact and inspect diagnostics; do not infer browser correctness from build success.
8. Report exact commit, workflow run, exit status and evidence locations.

## Tool catalogue metadata

Register the workspace executor and React/TypeScript inspector in `skill_tools`, then link them to the relevant coding/development/testing skills through `skill_tool_links`. Use `tool_type = 'cli'` for local scripts and `tool_type = 'library'` for the Playwright inspector package. Record the repository URL and tool paths in metadata/documentation fields.

## Safety and provenance

- Public workspace repository: never put private source or secrets in it.
- Only use the public checkout helper for public repositories; private repository access needs a separately designed short-lived credential flow.
- Target code is untrusted. It receives no repository write token or Supabase service credentials.
- Pin tool dependencies and preserve lockfiles.
- Every run should record target repository/ref/commit, environment ID/version, workflow run ID, exit status and artifact references.

## Synchronization status

This document defines the intended Supabase skill/tool mapping. The Supabase project schema was inspected and confirms the normalized skill/tool tables exist with RLS enabled. The connected database read/write operation for inspecting or updating individual skill records was blocked in this session; no Supabase skill rows or tool links have been changed yet. Do not claim the database catalogue is synchronized until those rows are verified.
