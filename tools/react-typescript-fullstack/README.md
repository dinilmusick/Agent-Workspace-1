# React + TypeScript full-stack inspection tool

Permanent reusable tooling for checking React/TypeScript applications. Target repositories are checked out at runtime under `workspaces/target`; never commit target application source here.

## Runtime contract

- Node.js 22+
- npm, pnpm, or Yarn lockfile detection
- Existing `dev` script required for browser inspection
- Playwright Chromium

The workflow installs the target project's dependencies, runs available build/test scripts, starts its `dev` script, and executes browser inspection. Outputs are written to `artifacts/` and uploaded by GitHub Actions.

## Evidence

`artifacts/browser/` contains screenshots, a DOM snapshot, JSON diagnostics and a Playwright trace. Diagnostics include console errors, uncaught page exceptions, failed requests and HTTP responses with status >= 400.

This is a diagnostic baseline, not a claim of complete visual correctness. Add application-specific Playwright assertions as the test catalogue grows.
