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
5. Runs manifest-driven Playwright Test against real target routes and user workflows.
6. Captures responsive screenshots, DOM snapshots, console/network/HTTP failures, traces, and axe-core results.
7. Compares configured visual baselines; baseline updates are opt-in.
8. Uploads evidence even when an earlier stage fails.

## Evidence

`artifacts/` contains install/build/test/quality logs plus:
- screenshot and DOM text snapshot;
- browser console errors and uncaught page exceptions;
- failed network requests and HTTP responses with status >= 400;
- Playwright trace;
- axe accessibility violations, passes and incomplete checks.

## Browser test manifest

Add `.agent-workspace/browser-tests.json` to a target repository. Version 1 supports explicit `routes` with title/heading/visible assertions, named `viewports`, `authStates` backed by target-local Playwright storage-state files, and declarative `workflows` with navigation, click, fill, check, select, visibility, text, URL and enabled assertions. Routes in Next.js App Router and Pages Router are discovered automatically; dynamic routes are listed as untested until concrete paths are supplied.

Set `visual.enabled` to true and `visual.baselineDir` to a target-local directory to enable `toHaveScreenshot` comparisons. Baselines are never overwritten by default. Set `UPDATE_VISUAL_BASELINES=1` only when intentionally refreshing them; the workflow uploads generated baselines as evidence. Accessibility checks use axe-core and can be configured to fail on violations.

The CI browser-harness workflow starts the real Node sample application, exercises its login and mobile navigation flows, generates baselines once, then runs a second comparison pass. Its report labels this as a real preview; fixture or static-only checks are never represented as application preview evidence.
