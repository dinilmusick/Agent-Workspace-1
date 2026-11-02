# React + TypeScript full-stack inspection tool

Permanent reusable tooling for checking React/TypeScript applications. Target repositories are checked out at runtime under `workspaces/target`; never commit target application source here.

## Runtime contract

- Node.js 22+
- npm, pnpm or Yarn lockfile detection
- React application with a `dev`, `start` or `preview` script
- Playwright Chromium

## Installed toolchain

Pinned in `package.json` and `package-lock.json`:

- TypeScript 6.0.3
- ESLint 10 + typescript-eslint 8
- Prettier and Biome
- Vitest
- Playwright
- axe-core / @axe-core/playwright
- Knip
- dependency-cruiser

The quality runner uses each tool only when the target project provides its corresponding configuration. ESLint 10 requires flat config (`eslint.config.js/mjs/cjs/ts`); legacy `.eslintrc` is not supported.

## Workflow

The manual `.github/workflows/inspect-react.yml` workflow:
1. Checks out a public target repository into the disposable workspace.
2. Installs its locked dependencies and runs available build/test scripts.
3. Runs configured type, lint, format, unused-code and dependency-boundary checks.
4. Starts the target application and waits for HTTP readiness.
5. Inspects the actual rendered page with Playwright and axe-core.
6. Uploads evidence even when an earlier stage fails.

## Evidence

`artifacts/` contains install/build/test/quality logs plus:
- screenshot and DOM text snapshot;
- browser console errors and uncaught page exceptions;
- failed network requests and HTTP responses with status >= 400;
- Playwright trace;
- axe accessibility violations, passes and incomplete checks.

This is a diagnostic baseline, not a claim of complete visual correctness. Add application-specific Playwright assertions as the test catalogue grows.
