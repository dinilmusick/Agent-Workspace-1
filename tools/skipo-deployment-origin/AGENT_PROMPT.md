# Agent Task: Standardize Skipo Deployment-Origin Configuration for Luth

## Objective

Implement and independently verify one canonical deployment-origin contract across the Skipo ecosystem.

The canonical environment variable name is **APP_URL**. The existing Skipo canonical Next.js and Vite scaffolds already establish APP_URL in their environment contract. Do not introduce DEPLOYMENT_URL, APP_ORIGIN, PUBLIC_URL, or another parallel name.

The contract is:

APP_URL
  -> identifies the deployment origin of the current application
  -> is available to backend/server code when a browser does not exist
  -> is submitted to Luth as the application's `origin` during application registration
  -> is used by Luth itself as the canonical Better Auth `baseURL`

Browser origin discovery may remain as a browser-side fallback/override where appropriate, but it must no longer be the only way to determine the application deployment origin.

## Target repositories

Implement across:

1. dinilmusick/Skipo
2. dinilmusick/GutTS
3. dinilmusick/Kloks
4. dinilmusick/Luth
5. dinilmusick/Aiko
6. dinilmusick/Depm-Engine
7. dinilmusick/Qwnsr-Engine
8. dinilmusick/DocuStack-Engine
9. dinilmusick/Srkl-Engine
10. dinilmusick/Fod-Engine
11. dinilmusick/Theta-Engine
12. dinilmusick/Kult-Engine
13. dinilmusick/Kelt-Engine

Treat current repository source as canonical. Inspect every affected implementation before editing.

## Required architecture

### 1. Skipo canonical scaffold

Both canonical scaffolds must expose APP_URL:

- `scaffolds/nextjs/.env.example`
- `scaffolds/vite/.env.example`
- typed environment access in both scaffold variants
- generated deployment configuration where applicable

APP_URL is a non-secret deployment-origin setting.

The scaffold contract must make clear:

APP_URL = current application's canonical public deployment origin.

Do not remove existing Luth URL variables such as NEXT_PUBLIC_LUTH_URL/VITE_LUTH_URL; those identify the Luth authority, not the current application's origin.

Add/update scaffold tests so generated apps cannot regress to browser-only origin discovery.

### 2. GutTS canonical auth client

The canonical Luth client in GutTS must resolve application origin in this order:

1. explicit `origin` supplied by caller
2. browser `window.location.origin`, when a browser exists
3. `APP_URL` from the runtime environment, when no browser exists
4. otherwise an explicit empty/invalid-origin failure path rather than silently inventing an origin

The implementation must work in Node/server/worker contexts without `window`.

Do not put APP_URL into browser-exposed configuration unless the runtime already intentionally exposes it. The important requirement is server/non-browser fallback.

Add tests covering:

- explicit origin wins
- browser origin works
- APP_URL works without window
- missing origin is observable
- registration sends the resolved origin
- environment classification remains correct

### 3. Kloks

Preserve Kloks as the public auth integration surface over GutTS.

Update only what is necessary so the public Kloks auth API and tests expose the canonical behavior without creating a second implementation.

No local auth authority may be introduced.

### 4. Luth

Luth must use **APP_URL** as its own deployment URL.

Update the Luth environment contract so APP_URL is required for deployed runtime configuration.

Better Auth must receive:

`baseURL = normalized APP_URL origin`

Do not use the request/browser URL as the authoritative Better Auth base URL in production.

The Luth request URL may still be used for request routing/CORS context, but it must not silently replace APP_URL for Better Auth configuration.

Update:

- `LuthEnv`
- Better Auth initialization
- universal entry/callers
- environment validation
- tests
- Wrangler configuration

The Cloudflare Worker deployment must contain:

- ASSETS
- SYSTEM_DATABASE_URL (with existing optional database fallbacks if supported)
- APP_URL as a **plain-text, non-secret** variable

Remove/reject all legacy Better Auth runtime variables as already established:

- BETTER_AUTH_SECRET
- BETTER_AUTH_URL
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET
- LUTH_ALLOWED_ORIGINS

Better Auth secret and Google credentials remain in the canonical system database.

Luth's APP_URL production value is:

https://luth.blueprint-ninjastudios.workers.dev

Do not hardcode that value into application logic; configure it through APP_URL.

### 5. All nine Skipo client applications

Every client app must have APP_URL in its runtime/deployment environment contract.

For each app:

- inspect existing `.env.example`, Wrangler/Vercel configuration, environment resolver and Luth client wiring;
- replace browser-only origin discovery where server-side Luth registration/session flows need the application origin;
- ensure the resolved APP_URL is passed to the canonical Luth client or otherwise reaches the canonical origin resolver;
- preserve browser origin behavior for actual browser requests where that is desirable;
- remove obsolete deployment-origin variables that duplicate APP_URL.

Do not invent production URLs. Discover existing deployment URLs from repository configuration, hosting configuration, existing registration records, or verified deployment metadata. If a production URL cannot be safely established, configure the variable contract and record the exact remaining external configuration requirement rather than guessing.

### 6. Depm-specific migration

DEPM currently has:

`DEPM_GATEWAY_DOMAIN`

This variable is to be completely replaced by:

`APP_URL`

Update all DEPM code/config/tests/docs that consume DEPM_GATEWAY_DOMAIN.

In particular:

- Wrangler `[vars]`
- `.env.example`
- environment access
- gateway/origin logic
- Luth registration
- tests

After migration there must be no runtime dependency on DEPM_GATEWAY_DOMAIN.

APP_URL must represent the DEPM deployment origin, not the Luth URL.

### 7. Cross-origin registration contract

The registration request sent to Luth must have the conceptual shape:

{
  ecosystemId,
  applicationId,
  origin: resolvedApplicationDeploymentOrigin,
  environment
}

The origin must be:

- explicit caller origin when deliberately supplied;
- browser origin in browser runtime;
- APP_URL in non-browser/server runtime.

Never send Luth's own URL as the client application's origin.

### 8. Security

APP_URL is not a secret.

Do not place secrets into APP_URL.

Do not use APP_URL for authentication credentials.

Do not weaken Luth trusted-origin/security validation merely to make registration succeed.

Luth remains the sole authentication authority.

## Agent-Workspace execution protocol

Use Agent-Workspace-1 as the execution substrate.

For each private target repository:

1. Clone it into the Agent-Workspace dedicated clone area.
2. Inspect branch/worktree state before editing.
3. Preserve unrelated user work.
4. Implement and test locally first.
5. Use the repository's existing package manager and CI commands.
6. Add comprehensive targeted tests as part of the implementation.
7. Commit coherent changes.
8. Run native GitHub CI when available and useful.
9. If native private CI is unavailable/exhausted/blocked, use the existing Agent-Workspace private-repo CI fallback:
   - .agent/ci-request.json
   - .github/workflows/private-repo-ci.yml
   - pinned act
   - target workflow validation
   - captured logs/evidence
10. Never expose coding/deployment credentials to target workflows.
11. Clean credentialed clones after verification.

For upstream dependency changes:

GutTS/Kloks/Floks/KrnlTS/FrnlTS changes must be tested through local package wiring first. Do not publish npm merely to make a test pass. Publish/update downstream package versions only after the upstream implementation is verified.

## Verification requirements

Completion requires all of these:

### Static/source verification

- Skipo scaffolds contain APP_URL contract.
- Nine client applications contain APP_URL contract.
- DEPM_GATEWAY_DOMAIN is absent from DEPM runtime/config/source.
- Luth contains APP_URL and no legacy Better Auth environment authority.
- Better Auth baseURL comes from Luth APP_URL.
- GutTS origin resolver works without browser globals.
- No duplicate deployment-origin implementation exists.

### Automated tests

Run affected:

- GutTS auth tests
- Kloks auth tests
- Skipo scaffold/authentication tests
- Luth environment/auth/configuration tests
- each affected client application's lint/typecheck/unit tests
- DEPM-specific tests
- builds for affected deployment targets

### Runtime verification

At minimum verify:

1. Luth health endpoint.
2. Luth Better Auth endpoint using its configured APP_URL.
3. Luth application registration from a real/non-browser-style request using an explicit APP_URL-derived origin.
4. A browser request still resolves the actual browser origin correctly.
5. A server/non-browser request resolves APP_URL correctly.
6. A client registration reaches Luth with the client's deployment origin.
7. Luth stores/recognizes the client's origin through the existing registry.
8. CORS/trusted-origin behavior accepts the registered client origin and rejects unrelated origins.
9. DEPM registration uses APP_URL after removing DEPM_GATEWAY_DOMAIN.
10. Authentication lifecycle remains functional: registration, sign-in, Google OAuth configuration path, session hydration, refresh, logout/revocation.

Do not claim runtime success from source inspection alone.

## Independent verification

The implementing worker must not be the sole verifier.

After implementation:

- inspect the final diffs;
- run the complete affected test/CI evidence;
- use a separate verification pass/agent identity to inspect the implementation and evidence;
- specifically verify the origin value at the Luth registration boundary;
- verify the deployed Luth Worker bindings contain APP_URL and SYSTEM_DATABASE_URL and no obsolete Better Auth secrets;
- verify the production Luth Better Auth base URL behavior.

If an obstacle occurs, use the Agent-Workspace obstacle reflex:

observe
-> normalize
-> semantic-search canonical obstacle memory
-> record occurrence/evidence
-> fix root cause
-> rerun
-> independently verify
-> update reusable skill/workflow if the obstacle is a substrate weakness.

## Completion invariant

Do not mark complete until:

SourceContractPassed
AND
TestsPassed
AND
BuildsPassed
AND
LuthRuntimePassed
AND
ClientRegistrationOriginVerified
AND
DepmMigrationVerified
AND
IndependentVerificationPassed
AND
AllRequiredCI/EvidenceCaptured

If any criterion is unknown, report it as unknown rather than passing it.

## Final report

Return:

- repositories changed
- commits
- exact APP_URL contract
- old variables removed/replaced
- tests/builds run
- CI run IDs
- runtime verification evidence
- independent verification evidence
- remaining external configuration, if any
- obstacles encountered and their resolutions


<!-- validation gate: APP_URL ecosystem reconciliation -->
