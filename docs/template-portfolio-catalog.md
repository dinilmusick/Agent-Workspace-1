# ULTRST Software Starter Portfolio — Coverage and Acquisition Manifest

Snapshot: 2026-11-13 (UTC)  
Vision: [ULTRST Universal Software Portfolio & Ecosystem Absorption](https://github.com/dinilmusick/Agent-Workspace-1/blob/main/docs/template-portfolio-candidates.md)  
Coordination: Supabase vision key `ultrst-universal-software-portfolio-ecosystem-absorption`

This catalog is the working coverage map for the first broad software-starter portfolio. It deliberately includes web applications, backend products, developer infrastructure, data systems, mobile/desktop software, automation, AI products and industry-specific systems. Programming language is not a selection constraint.

**Acquisition meaning:** a private mirror is for internal inspection, testing, learning and architectural reference. It is not commercial-license clearance. The upstream LICENSE, NOTICE, copyright headers, attribution and all applicable terms remain in force. No copied project may be redistributed, shipped in a client deliverable or offered as a hosted service until its complete source, dependency, asset, model, font, trademark and distribution obligations have been independently cleared. Where GitHub does not identify a recognized open-source license, the acquisition workflow must create a reference-only repository without copying source files.

## 1. Existing portfolio repositories

These nine repositories already exist under `dinilmusick`; do not recreate them.

| Coverage | Existing repository | Current fit / follow-up |
|---|---|---|
| Documentation websites | [tpl-docs-docusaurus](https://github.com/dinilmusick/tpl-docs-docusaurus) | Docusaurus documentation-site generator and docs-site foundation. |
| Static websites / landing sites | [tpl-static-hugo](https://github.com/dinilmusick/tpl-static-hugo) | Hugo static-site generator; use for content-driven static sites, portfolios and marketing sites. |
| Knowledge base / internal wiki | [tpl-knowledge-bookstack](https://github.com/dinilmusick/tpl-knowledge-bookstack) | BookStack product mirror; inspect branch, license and runnable setup before using as a commercial starter. |
| SaaS application | [tpl-saas-nextjs](https://github.com/dinilmusick/tpl-saas-nextjs) | Next.js/Postgres/Stripe SaaS application starter with auth, teams, subscription management and dashboard. |
| Admin dashboard / CRUD application | [tpl-admin-refine](https://github.com/dinilmusick/tpl-admin-refine) | Refine app framework with working CRUD examples; framework plus examples, not a single finished vertical product. |
| Project management / Kanban | [tpl-project-kanboard](https://github.com/dinilmusick/tpl-project-kanboard) | Kanboard is functional but its README explicitly says it is in maintenance mode. Retain as a legacy baseline; compare with Plane before selecting a default. |
| Community forum | [tpl-community-flarum](https://github.com/dinilmusick/tpl-community-flarum) | Flarum skeleton application; its README says most core development occurs in a separate repository. Pair with the full NodeBB mirror below. |
| Automation / event-driven flows | [tpl-automation-nodered](https://github.com/dinilmusick/tpl-automation-nodered) | Node-RED full automation runtime and visual flow editor. |
| Durable workflow orchestration | [tpl-orchestration-temporal](https://github.com/dinilmusick/tpl-orchestration-temporal) | Temporal server / durable execution platform. |

## 2. Additional full-source private research mirrors

These are the proposed missing functional projects. The commit is pinned to the upstream default-branch head observed on 2026-11-12. The acquisition workflow re-checks that the source branch still points to this commit before mirroring.

| Product category | Upstream source | Destination repository | Branch | GitHub SPDX | Pinned source commit | Why it is included |
|---|---|---|---|---|---|---|
| Headless CMS / content platform | [payloadcms/payload](https://github.com/payloadcms/payload) | `tpl-cms-payload` | main | MIT | `7a80820ce48dc71420d92e32ca076dc7d004375e` | Full TypeScript CMS, admin UI, APIs and extensible content model. Existing audit remains CONDITIONAL for commercial use. |
| E-commerce + multi-vendor marketplace | [spree/spree](https://github.com/spree/spree) | `tpl-commerce-spree` | main | BSD-3-Clause | `9af32fb49de0e0c2a7aef41044046e272646fcb9` | REST API, TypeScript SDK, storefront and marketplace / B2B use cases in one source project. |
| CRM / sales pipeline | [krayin/laravel-crm](https://github.com/krayin/laravel-crm) | `tpl-crm-krayin` | 2.2 | MIT | `ed6deebfcb8c616eaf352c893a10a6d8e666fc6e` | Complete Laravel CRM. Existing audit rejected the exact dependency set for commercial reuse; private study only. |
| ERP / business operations | [apache/ofbiz-framework](https://github.com/apache/ofbiz-framework) | `tpl-erp-ofbiz` | trunk | Apache-2.0 | `59b32bdc3bed4abdeb9b5eaa12f5d605a3926985` | Broad Java ERP / commerce / order and business-process system. Full dependency and bundled-JAR audit remains required. |
| Python full-stack API application | [fastapi/full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template) | `tpl-backend-fastapi` | master | MIT | `aabb90126964a164e02aff39e7c385bb0598236d` | Complete API + database + frontend starter. Existing audit rejected the current lockfile graph for commercial reuse; private study only. |
| RAG / document intelligence | [infiniflow/ragflow](https://github.com/infiniflow/ragflow) | `tpl-ai-ragflow` | main | Apache-2.0 | `03b0c0ae04ab30e44796b927a3c0229b1a440358` | Functional document-understanding RAG engine with retrieval and agent capabilities. Dependency/model/asset audit remains separate. |
| Visual AI agent and workflow builder | [langflow-ai/langflow](https://github.com/langflow-ai/langflow) | `tpl-ai-langflow` | main | MIT | `2cf9ce808afa6ad3f41aa5f6b47bdcb1927cde84` | Visual agent, LLM and MCP workflow builder. |
| Self-hosted PaaS / deployment control plane | [dokku/dokku](https://github.com/dokku/dokku) | `tpl-deployment-dokku` | master | MIT | `bf03afb9810caea112f2ea2e203b21da4f84c382` | Self-hosted application deployment platform. Existing audit is CONDITIONAL pending plugin/module and bundled-helper review. |
| Inventory / manufacturing operations | [inventree/InvenTree](https://github.com/inventree/InvenTree) | `tpl-inventory-inventree` | master | MIT | `7e57196d76f4560caebbff9508ea5e230341fc08` | Full inventory and parts-management product. Existing audit found LGPL runtime dependencies; private study only. |
| Healthcare / FHIR platform | [medplum/medplum](https://github.com/medplum/medplum) | `tpl-health-medplum` | main | Apache-2.0 | `e7e7e40191440fca0d06ded9d2b56c11c639058f` | Full healthcare interoperability platform and FHIR server. Existing audit found an unlicensed bundled font; private study only until corrected. |
| Appointment scheduling / booking | [calcom/cal.diy](https://github.com/calcom/cal.diy) | `tpl-booking-caldiy` | main | MIT | `ef7954d16ab50882ca2f263c551537115b8a8bb1` | Active self-hosted appointment-scheduling application. Treat as the community Cal.diy project, not a statement about Cal.com licensing. |
| BI / analytics dashboards | [apache/superset](https://github.com/apache/superset) | `tpl-bi-superset` | master | Apache-2.0 | `8d5f06e5250230e55f7d953ab807af271d1ed01b` | Mature business-intelligence and data-visualization application. |
| ELT / data integration | [meltano/meltano](https://github.com/meltano/meltano) | `tpl-data-meltano` | main | MIT | `3913352432f32632e16807142111455d5f64cb89` | Declarative, code-first ELT and connector platform. |
| Mobile application starters | [expo/examples](https://github.com/expo/examples) | `tpl-mobile-expo-examples` | master | MIT | `2cc7a440b01eb30e326b91cf1f3aae41e749d128` | Official working examples across Expo / React Native mobile use cases. |
| Desktop application framework (Rust) | [tauri-apps/tauri](https://github.com/tauri-apps/tauri) | `tpl-desktop-tauri` | dev | Apache-2.0 | `5edd31c8a8914674c217b21a660a914823da2dae` | Native desktop/mobile runtime and examples for web-fronted Rust applications. |
| Desktop application starter (Electron) | [electron-react-boilerplate/electron-react-boilerplate](https://github.com/electron-react-boilerplate/electron-react-boilerplate) | `tpl-desktop-electron` | main | MIT | `e5b8242d8b21a4290c3a1f18ae3b64167e9de04a` | Complete Electron + React desktop starter. |
| Browser extensions | [wxt-dev/wxt](https://github.com/wxt-dev/wxt) | `tpl-browser-wxt` | main | MIT | `a71b42694c26e6e5189e50fdfbb83852629005e2` | Cross-browser extension framework with MV2/MV3, TypeScript, HMR and publishing support. |
| CI/CD platform | [woodpecker-ci/woodpecker](https://github.com/woodpecker-ci/woodpecker) | `tpl-cicd-woodpecker` | main | Apache-2.0 | `67c1b3e85644211049c2a151ffb2d8b14d5fde3d` | Self-hostable CI/CD server and pipeline system. |
| Infrastructure as code | [pulumi/pulumi](https://github.com/pulumi/pulumi) | `tpl-iac-pulumi` | master | Apache-2.0 | `a4fcfbebd8f7232544eac62176503c6923d931fd` | Multi-language infrastructure-as-code engine and provider ecosystem. |
| Video conferencing / WebRTC | [jitsi/jitsi-meet](https://github.com/jitsi/jitsi-meet) | `tpl-video-jitsi` | master | Apache-2.0 | `f731310dc4b6f26fb3dc9a78f87b23a596dfbb18` | Full self-hostable video-meeting product and embeddable meeting UI. |
| Subscription billing / payments | [killbill/killbill](https://github.com/killbill/killbill) | `tpl-billing-killbill` | master | Apache-2.0 | `52e2f55f103baf0703ddee71e10a7036595fc851` | Mature subscription billing and payments platform. |
| Modern project management | [makeplane/plane](https://github.com/makeplane/plane) | `tpl-project-plane` | preview | AGPL-3.0 | `9cefae892c4c28ee60400abca12e4ababe74cf96` | Newer complete project-management product to compare with the existing maintenance-mode Kanboard. Pinned default branch is preview. |
| Full community / forum platform | [nodebb/nodebb](https://github.com/NodeBB/NodeBB) | `tpl-community-nodebb` | master | GPL-3.0 | `b04f482eb068e9421bed35c335232164a27fc5b5` | Full Node.js community discussion platform; complements the existing Flarum skeleton. |
| HRMS | [frappe/hrms](https://github.com/frappe/hrms) | `tpl-hrms-frappe` | develop | GPL-3.0 | `acc4b3a70a6ac52ae6de175df22a5855f428d067` | Human-resources application with employee, leave, payroll and related workflows. |
| LMS / education | [moodle/moodle](https://github.com/moodle/moodle) | `tpl-lms-moodle` | main | GPL-3.0 | `afbcc55fa1bd80dcdd887b8965dd8c28c0f3bbda` | Full learning-management platform for courses, users, assessments and learning workflows. |
| Social network / federated publishing | [mastodon/mastodon](https://github.com/mastodon/mastodon) | `tpl-social-mastodon` | main | AGPL-3.0 | `ca8b0ffac86cc5b064a4573f16b8061716c8ab6f` | Complete federated social-network product. |
| Document management / archive | [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) | `tpl-documents-paperless` | dev | GPL-3.0 | `a1d76f3a19c9bf7067491de6f0a12672676ae9f1` | Full document ingestion, OCR, tagging and archive application. |
| Cloud security assessment | [prowler-cloud/prowler](https://github.com/prowler-cloud/prowler) | `tpl-cloud-security-prowler` | master | Apache-2.0 | `163343b55259eadbe559bd87226d6b8a60576286` | Multi-cloud security posture assessment and reporting tool. |
| Data workflow orchestration | [apache/airflow](https://github.com/apache/airflow) | `tpl-data-airflow` | main | Apache-2.0 | `ea7677ed17271db01fa5ce83d708b2c58c88984b` |Production-grade DAG-based workflow scheduling and execution; refreshed after review of a 7-commit fast-forward adding Beam/Dataflow job-ID discovery and async process handling, Microsoft Graph operators/sensors/triggers and tests; preserve Apache LICENSE/NOTICE and separately audit providers/dependencies. acquired-and-verified; original issue #809 and refresh issue #900; workflow run 43385480697; independent read-only verifier passed; root pyproject.toml exactly matches pinned upstream.|

## 3. Additional reference-only candidates

GitHub did not provide a recognized SPDX license identifier for these exact repository snapshots, or their license contains additional conditions requiring specific review. The private acquisition workflow must create only a README provenance record for these; it must not copy upstream code or assets.

| Product category | Upstream source | Destination reference | Branch | Observed source commit | Reason for reference-only treatment |
|---|---|---|---|---|---|
| Customer support / helpdesk | [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) | `tpl-helpdesk-chatwoot` | develop | `0784e4aa342f76847623151989e717779b831250` | GitHub API returned NOASSERTION; inspect the complete root and dependency license data before mirroring. |
| IoT / device management | [thingsboard/thingsboard](https://github.com/thingsboard/thingsboard) | `tpl-iot-thingsboard` | master | `2ca21716d47d1801560df9d82bf68fede610508e` | GitHub API returned NOASSERTION; root licensing and edition boundaries need manual review. |
| Search service / search engine | [meilisearch/meilisearch](https://github.com/meilisearch/meilisearch) | `tpl-search-meilisearch` | main | `1b782653f25c6ff70084c1a510cd6d2608af458d` | GitHub API returned NOASSERTION; verify the exact license and edition boundary before mirroring. |
| Event ticketing / event operations | [pretix/pretix](https://github.com/pretix/pretix) | `tpl-events-pretix` | master | `137059dd4e7a7f4643199323b69a85824bffc28e` | License includes special additional terms and service-purpose restrictions; do not mirror automatically. |
| AI product / agentic workflow workspace | [langgenius/dify](https://github.com/langgenius/dify) | `tpl-ai-dify` | main | `32ee51ca542c10a2c0cec3fb836ef549fc117a22` | Dify Open Source License contains added conditions; use reference-only until reviewed. |
| Automation / app integration | [n8n-io/n8n](https://github.com/n8n-io/n8n) | `tpl-automation-n8n` | master | `df043ec5bedd736c437c5e962845b47dc7436635` | Sustainable Use / fair-code terms; reference-only. Existing Node-RED remains the open-source automation starter. |

## 4. Coverage summary and consolidation rules

- Existing repositories: **9**.
- Additional full-source research mirrors proposed: **29**.
- Additional reference-only records proposed: **6**.
- Portfolio map after acquisition: **44 repositories/records**, without duplicating the same upstream project for multiple categories.
- Spree is deliberately shared across e-commerce and marketplace use cases; do not make a second mirror of the same upstream project.
- Temporal is the general durable-workflow engine; Airflow is the data-pipeline scheduler. Keep these distinct.
- Node-RED is the main open-source visual automation starter; n8n is only a reference until its license terms are separately cleared.
- Existing Kanboard is retained as a functional legacy baseline; Plane is a comparative modern project-management candidate, not an automatic replacement.
- Existing Flarum is a skeleton app; NodeBB supplies a complete alternative forum product.
- Some candidates are tools/frameworks rather than complete client-facing apps. Their role is reusable product infrastructure; the later absorption phase must identify actual application capabilities and produce domain-specific starters when needed.

## 5. Required next steps

1. Record this catalogue and verify every source's exact branch head.
2. Use the Agent Workspace private acquisition workflow for each approved full-source research mirror; create reference-only records for the six restricted/uncertain candidates.
3. Verify each destination is private, non-fork, has the expected default branch and exact pinned commit, and contains no upstream remote.
4. Run isolated setup/build/test/smoke checks per project where practical; store the result and any required environment prerequisites.
5. Only after acquisition verification, begin capability decomposition and absorption into the corresponding language ecosystems.
6. Before any commercial reuse, repeat the full legal/dependency/asset audit against the exact product configuration and source revision.

The catalog is a coverage plan, not a claim that every proposed destination has already been created or independently tested.


## 6. Acquisition and validation priority

Ranking is based on product breadth and likely paid-project reuse first, then the usefulness of the codebase as a reusable implementation. GitHub stars and recent activity are maturity signals, not proof of software quality or commercial suitability.

### Priority A — client-delivery starters with broad reuse

1. CMS and content platforms — Payload.
2. E-commerce and marketplaces — Spree.
3. SaaS applications — existing Next.js SaaS starter.
4. CRM and sales operations — Krayin.
5. API-first backend applications — FastAPI full-stack template.
6. AI application and agent workflows — Langflow.
7. RAG and document intelligence — RAGFlow.
8. Booking and scheduling — Cal.diy.
9. Admin dashboards and internal tools — Refine.
10. BI and analytics dashboards — Apache Superset.
11. Customer support and helpdesk — Chatwoot reference candidate (license metadata unresolved).
12. Subscription billing — Kill Bill.
13. Automation and integrations — existing Node-RED; n8n reference candidate.
14. Business websites and documentation — existing Hugo and Docusaurus.
15. Commerce operations / order workflows — Spree plus the existing SaaS and API foundations.

### Priority B — high-value specialist application starters

16. ERP / business operations — Apache OFBiz.
17. Inventory and manufacturing — InvenTree.
18. Healthcare interoperability — Medplum.
19. HRMS — Frappe HRMS.
20. LMS / education — Moodle.
21. Event ticketing — pretix reference-only.
22. Project management — Plane compared with existing Kanboard.
23. Community / forum software — NodeBB compared with existing Flarum skeleton.
24. Federated social network — Mastodon.
25. Document management and archive — Paperless-ngx.
26. Video conferencing — Jitsi Meet.
27. Mobile applications — Expo examples.
28. Desktop applications — Tauri and Electron starters.
29. Browser extensions — WXT.

### Priority C — foundational infrastructure and specialist engineering tools

30. General workflow orchestration — existing Temporal.
31. Data workflow orchestration — Apache Airflow.
32. ELT / integration pipelines — Meltano.
33. Self-hosted PaaS — Dokku.
34. CI/CD platform — Woodpecker.
35. Infrastructure as code — Pulumi.
36. Cloud security assessment — Prowler.
37. IoT / device management — ThingsBoard reference-only.
38. Search infrastructure — Meilisearch reference-only.

Acquisition order should follow the priorities, but the manifest pins each candidate independently so parallel private acquisition can proceed once the discovery goal is verified. No product is marked commercially cleared by this ranking.


## 5. Live upstream-head refresh and pin review — 2026-11-12

All 35 additional upstream default-branch heads were re-queried against GitHub. Thirty pins remained exact. Five catalog pins had moved and were refreshed only after reviewing the new commit metadata and patches:

| Destination | Refreshed source commit | Reviewed change | Decision |
|---|---|---|---|
| `tpl-bi-superset` | `58a1a5c7e8f759383573ba15ba509e8d1bc49015` | `8d5f06e5250230e55f7d953ab807af271d1ed01b` | 5-commit fast-forward. Docker base-image digests and pinned docker/login-action 4.7.0→4.8.0 updated; Babel, AG Grid 36.2.0→36.3.0, ag-charts-types 14.2.0→14.3.0, and docs oxfmt 0.75.0→0.76.0 refreshed. Frontend/docs package locks changed; no Python runtime manifest change. LICENSE.txt Apache-2.0 and NOTICE ASF attribution unchanged. | Accept for private research mirror; Docker images, frontend/docs dependencies and assets require separate audit. |
| `tpl-data-meltano` | `23fab6f99554b0de7ce17d6ede3b8a45bc3234a9` | `3913352432f32632e16807142111455d5f64cb89` | 2-commit fast-forward, docs-only: follow-redirects 1.16.1→1.16.3 and minimatch 10.2.6→11.0.1. The latter adds `@isaacs/nonrecursive-glob-match`, locked as BlueOak-1.0.0. No runtime Python manifest or `uv.lock` change. Root MIT LICENSE unchanged; no root NOTICE. | Accept for private research mirror; BlueOak-1.0.0 and all transitive licenses require separate audit. |
| `tpl-data-airflow` | `e024d4c15a52a843c28aa773c2d5db69fe21deea` | `2617656daf5db195a088489f4c8195f842df6ee1` | 10-commit fast-forward (6 previously reviewed commits plus 4 additional commits to current `main`; zero behind). The original range adds durable-agent toolset IDs, per-attempt execution controls, journal/state-store efficiency and retry correctness, AI provider docs/code/tests, `pydantic-ai-slim` floor 2.36.0→2.46.0 and `uv.lock`, plus fork-CI/project-CI merge gating. The additional 4 commits update core UI dependencies/lockfile: TanStack Query 5.106.1→5.107.1, react-resizable-panels 4.18.1→4.19.1, Zustand 5.0.16→5.1.0, Playwright 1.64.1→1.65.0, MSW 3.0.3→3.0.4, oxfmt 0.75.0→0.77.0 and oxlint 1.90.0→1.92.0; fix PostgreSQL session-level advisory-lock parameter handling to avoid psycopg3 idle-transaction snapshots blocking `CREATE INDEX CONCURRENTLY` (with regression test); and add `SQLToolsetConnectionError` so database reachability failures fail durable attempts for retry instead of being replayed as model-correctable SQL errors (statement errors remain `ModelRetry`), with provider docs/tests. Root Apache-2.0 LICENSE and ASF NOTICE unchanged; no legal-file changes in reviewed range. | Accept for private research mirror; re-audit provider extras, UI dependencies/assets, SQL connection semantics and all transitive dependencies before any use. |
| `tpl-iot-thingsboard` | `2ca21716d47d1801560df9d82bf68fede610508e` | Merge updates the ThingsBoard AI model processor's Optional access to use the direct value accessor. | Accept pin for reference-only record; GitHub SPDX metadata remains NOASSERTION. |
| `tpl-automation-n8n` | `df043ec5bedd736c437c5e962845b47dc7436635` | Replaces two hard-coded editor dismiss-tooltip strings with the localized generic.dismiss translation. | Accept pin for reference-only record; GitHub SPDX metadata remains NOASSERTION. |


A subsequent live-head check found that Spree's default branch advanced after the earlier catalog refresh. The first two acquisition attempts correctly rejected the stale default-branch pin before modifying the destination. The new head was reviewed before refreshing the catalog:

| Destination | Previous pin | Reviewed current source commit | Reviewed change | Decision |
|---|---|---|---|---|
| `tpl-commerce-spree` | `ab8f82fc5d4f91beb42447f84df9106d79e7a39a` | `9af32fb49de0e0c2a7aef41044046e272646fcb9` | Two signed commits: Dependabot updates `peter-evans/create-pull-request` from 8.1.1 to 8.1.2; Spree fixes draft-order line removal so recalculation and status refresh occur after successful removal, rejected removals roll back under nested/order-lock transactions, and API/agent-tool/dashboard regression tests cover the behavior. Seven files changed; no dependency addition or license change identified. | Accept refreshed pin; BSD-3-Clause root metadata unchanged. |

The new Spree head is a two-commit fast-forward from the previous pin. GitHub reports the latest commit signature as verified. The catalog pin now records the reviewed current default-branch HEAD; the acquisition validator will recheck it at request time.


A subsequent live-head review found that RAGFlow's main branch advanced from `292e1717d60a8efcd48f1fa04d03923ac7579540` to `1fc73d125f0081dc3090835a96a4e45e13055e84`. The acquisition request correctly rejected the stale pin. The three-commit fast-forward was reviewed before refreshing the catalog:

| Destination | Previous pin | Reviewed current source commit | Reviewed change | Decision |
|---|---|---|---|---|
| `tpl-ai-ragflow` | `1fc73d125f0081dc3090835a96a4e45e13055e84` | `03b0c0ae04ab30e44796b927a3c0229b1a440358` | 11-commit fast-forward. Review includes wildcard-CORS removal from login/register (Authorization token exposure), PDF cross-page table geometry/preview, PaddleOCR model/API updates, agent retry/streaming/deferred-output fixes, common exponential backoff, and the frontend `src/ee` extension seam. No dependency manifests/lockfiles or root legal files changed; root LICENSE Apache-2.0, no root NOTICE. | Accept for private research mirror; model/assets/dependencies require separate audit. |

GitHub compare confirms the previous pin is an ancestor of the new main HEAD (three commits ahead, zero behind). All three commit signatures are verified. The acquisition validator will recheck the exact new HEAD at request time.

The acquisition validator requires each requested source, destination and exact commit to occur together in this catalog and independently requires that commit to equal the live default-branch HEAD at request time. A later branch movement therefore rejects acquisition until this catalog is refreshed and reviewed again.


### Agent 07 — collaboration and organizational software pin review — 2026-11-12

The six assigned repositories were rechecked against their live upstream default branches and GitHub SPDX metadata. Four pins were already exact. Two fast-forwarded upstream heads were reviewed commit-by-commit before updating the catalog:

| Destination | Default branch | Previous pin | Reviewed current HEAD | Compare | Review |
|---|---|---|---|---|---|
| `tpl-video-jitsi` | `master` | `224092bbd7050b0a031692d10cdfd486758c2539` | `f731310dc4b6f26fb3dc9a78f87b23a596dfbb18` | [3 commits ahead, 0 behind](https://github.com/jitsi/jitsi-meet/compare/224092bbd7050b0a031692d10cdfd486758c2539...f731310dc4b6f26fb3dc9a78f87b23a596dfbb18) | Two test-only changes improve visitor chat/poll/promotion coverage and synchronize breakout-room membership before chat assertions; one Catalan translation update. Four files; no dependency/lockfile, production API/backend, migration or root-license change. Two test commits have unverified signatures; the final locale commit is verified. |
| `tpl-social-mastodon` | `main` | `b31c484d97c9b7f109ecdcc3de140ac2e865fd4d` | `ca8b0ffac86cc5b064a4573f16b8061716c8ab6f` | [6 commits ahead, 0 behind](https://github.com/mastodon/mastodon/compare/b31c484d97c9b7f109ecdcc3de140ac2e865fd4d...ca8b0ffac86cc5b064a4573f16b8061716c8ab6f) | Frontend accessibility/media/button/icon refinements, emoji text-field handling, translations and alert deduplication with a reducer regression test. 43 files; no dependency/lockfile, backend/API, migration or root-license change. All six commit signatures are verified. |

The remaining four pins were independently confirmed at the live default-branch HEAD on 2026-11-12: `makeplane/plane` (`preview`, `9cefae892c4c28ee60400abca12e4ababe74cf96`), `NodeBB/NodeBB` (`master`, `b04f482eb068e9421bed35c335232164a27fc5b5`), `frappe/hrms` (`develop`, `acc4b3a70a6ac52ae6de175df22a5855f428d067`) and `moodle/moodle` (`main`, `afbcc55fa1bd80dcdd887b8965dd8c28c0f3bbda`). GitHub SPDX metadata matched catalog identifiers for all six: Apache-2.0, AGPL-3.0, GPL-3.0, GPL-3.0, GPL-3.0 and AGPL-3.0 respectively.

Legal-file inspection confirmed Jitsi's root Apache-2.0 license and Debian copyright notice (including a historical MIT attribution); Plane's AGPL-3.0 license, `COPYRIGHT.txt` and mandatory source-header policy; NodeBB's GPL-3.0 `LICENSE`; Frappe HRMS's GPL-3.0 `license.txt`; Moodle's GPL-3.0 `COPYING.txt` plus numerous bundled third-party license/NOTICE files; and Mastodon's AGPL-3.0 `LICENSE`, `AUTHORS.md` and separate font/icon/image license files. Preserve all such files verbatim. Moodle's recursive legal-file listing was truncated, and no complete transitive dependency-license audit was performed. These projects remain **PRIVATE-STUDY-MIRROR only**; no commercial reuse, distribution, deployment or feature/security/build approval is granted by this pin review.



### Airflow current-head review supplement — 2026-11-12

The catalog pin is advanced from `e17cecaabbb08681dddf3fc015307dbcc656a498` to live `apache/airflow:main` HEAD `2617656daf5db195a088489f4c8195f842df6ee1`. The full range from the original catalog pin `e024d4c15a52a843c28aa773c2d5db69fe21deea` is a 10-commit fast-forward (zero commits behind).

The four additional commits after the earlier six-commit review are: (1) core UI production/development dependencies and `pnpm-lock.yaml` updates (TanStack Query, react-resizable-panels, Zustand, Playwright, MSW, oxfmt and oxlint); (2) a PostgreSQL migration-lock change replacing a bound parameter in `pg_advisory_lock` with an integer literal, preserving the connection/session advisory lock while avoiding a psycopg3 idle-transaction snapshot that could block `CREATE INDEX CONCURRENTLY`, plus a PostgreSQL regression test; and (3) common AI-provider SQL toolset handling that distinguishes database reachability/configuration failures from statement errors using `SQLToolsetConnectionError`, enabling durable retries to reattempt the connection instead of replaying the same model error, with documentation and tests. No root legal-file changes occur in the range; Apache-2.0 LICENSE and ASF NOTICE are retained. This remains private research acquisition only.


### Acquisition pin refresh — 2026-11-12 (continued)

Before acquisition, current upstream default-branch heads were rechecked. The following fast-forward changes were reviewed and the catalog pins refreshed:

| Destination | New pinned HEAD | Review summary |
|---|---|---|
| `tpl-cicd-woodpecker` | `67c1b3e85644211049c2a151ffb2d8b14d5fde3d` | Three commits update web/docs dependency lockfiles and pre-commit configuration; no application logic or root legal-file changes identified in the reviewed diff. Recheck all transitive package licenses before reuse. |
| `tpl-iac-pulumi` | `a4fcfbebd8f7232544eac62176503c6923d931fd` | Six commits add per-version release workflow concurrency and generated Go/Node.js automation SDK API changes plus release changelog updates. No root legal-file changes identified in the reviewed diff. |
| `tpl-video-jitsi` | `f731310dc4b6f26fb3dc9a78f87b23a596dfbb18` | Two commits update translations and the pinned `lib-jitsi-meet` release artifact in package manifests/lockfile. Re-audit that external artifact and its license independently. |
| `tpl-project-plane` | `9cefae892c4c28ee60400abca12e4ababe74cf96` | One commit hardens editor lifecycle handling when the editor instance is destroyed and its storage is reset. |
| `tpl-cloud-security-prowler` | `163343b55259eadbe559bd87226d6b8a60576286` | Nine commits update cloud security checks/tests, API schemas, container/dependency lockfiles, changelog and documentation; re-audit all dependency and image changes. |
| `tpl-helpdesk-chatwoot` | `0784e4aa342f76847623151989e717779b831250` | Two commits adjust Google Translate validation and translation failure handling, add tests, and update Ruby dependency/security audit data and vendor attribution. Reference-only; no source mirror. |
| `tpl-iot-thingsboard` | `2ca21716d47d1801560df9d82bf68fede610508e` | 37 commits include Redis cache/cluster and integration-service changes, AI transport/token handling, edge/queue behavior, API-key changes and UI updates. Reference-only; no source mirror. |
| `tpl-ai-dify` | `32ee51ca542c10a2c0cec3fb836ef549fc117a22` | Current main HEAD refreshed; reference-only pending separate review of the Dify Open Source License and edition conditions. |
| `tpl-automation-n8n` | `df043ec5bedd736c437c5e962845b47dc7436635` | Current master HEAD refreshed; broad workflow/agent, backend, database and editor changes. Reference-only under Sustainable Use/fair-code terms. |

The exact commit pins remain subject to the acquisition controller's live default-branch and catalog authorization checks. This review is for private acquisition only and does not grant commercial-use clearance.


Airflow pin supplement — 2026-11-12: the live `apache/airflow:main` HEAD advanced from `6c2e7b3646062af0c72528869a211274a775e8c3` to `2617656daf5db195a088489f4c8195f842df6ee1` (2 commits ahead, 0 behind). The reviewed range adds team-scoped connection/variable context propagation to triggerer and task SDK execution, including secrets-backend/cache scoping, with tests; it also adjusts example DAG connection logging to print connection IDs rather than full connection objects. No root LICENSE/NOTICE changes were identified. Private research mirror only; dependency, provider and runtime audits remain separate.


n8n reference pin supplement — 2026-11-12: `n8n-io/n8n:master` advanced from `35e9b8b4eac241e37c0dc082b818248c7e780df8` to `df043ec5bedd736c437c5e962845b47dc7436635` (2 commits ahead, 0 behind). Reviewed changes adjust Weaviate vector-store insertion so clearing is handled in a pre-insert lifecycle hook with client closure on success/failure, and refine agent-builder/instance-AI conversation handoff and embedded chat behavior with tests. Reference-only; no source copied, and Sustainable Use/fair-code conditions remain applicable.


### Five reference/mirror pin refreshes — 2026-11-13

The five source pins rejected by the acquisition validator were rechecked against the observed live default-branch heads. Each old pin is an ancestor of the new head; the reviewed compare ranges are fast-forwards with zero commits behind. The new pins below are authorized for the existing acquisition modes only:

| Destination | New pin | Range review | Decision |
|---|---|---|---|
| `tpl-data-airflow` | `2617656daf5db195a088489f4c8195f842df6ee1` | 8 commits / 30 files. Reviewed API/plugin schema and generated OpenAPI changes, trigger/settings behavior and tests, Java SDK release-verification docs, provider metadata and example updates. Latest commit is documentation-only. No root LICENSE or NOTICE change identified in the range. | Accept private full-source research mirror under Apache-2.0; preserve LICENSE/NOTICE and separately audit provider extras, dependencies and assets. |
| `tpl-search-meilisearch` | `1b782653f25c6ff70084c1a510cd6d2608af458d` | 4 commits / 3 files. Cargo manifest/lockfile and release workflow changes; macOS release runner moves from macos-14 to macos-15. Latest commit only changes release CI runner. No root legal-file change in the compare range. | Accept reference-only README record; GitHub SPDX remains NOASSERTION, so no source copied. |
| `tpl-iot-thingsboard` | `2ca21716d47d1801560df9d82bf68fede610508e` | 12 commits / 29 files. Reviewed Redis cache/cluster transaction behavior, edge tenant checks, version parsing, report rendering/configuration, transport defaults and UI/reporting changes. Critically, modified Java files explicitly change SPDX headers to `Apache-2.0 AND BUSL-1.1`; this reinforces the existing reference-only boundary. | Accept reference-only README record; do not mirror source. GitHub SPDX remains NOASSERTION and individual files now carry mixed licensing. |
| `tpl-ai-dify` | `32ee51ca542c10a2c0cec3fb836ef549fc117a22` | 8 commits / 55 files. Reviewed agent-app service/controller contracts, response gateways, Docker configuration, unit tests and browser-test additions. Latest commit adds browser tests for annotation filters, archived logs, explore cards and tag search. No root legal-file change identified in the compare range. | Accept reference-only README record under Dify's additional license conditions; no source copied. |
| `tpl-automation-n8n` | `df043ec5bedd736c437c5e962845b47dc7436635` | 16 commits / 112 files. Range includes workflow/app publishing and binding APIs, workflow history settings/migration, expression-runtime ASCII handling and tests, skill-source lifecycle, telemetry/scaling, encryption, node organization and generated schema/lockfile updates. Latest commit lowers the architecture-boundary baseline from 87 to 86 issues. No root legal-file change identified in the compare range. | Accept reference-only README record under Sustainable Use/fair-code terms; no source copied. |

The refreshed pins are authorization for private research acquisition only. They do not establish commercial-use, redistribution, hosting, dependency, model, font, asset or trademark clearance. The acquisition workflow must still recheck each exact live default-branch HEAD when the request is processed.

## 6. Additional full-source private research mirrors — 2026-11-13

The following 16 candidates were audited for portfolio duplication, current default branch, source activity, approximate GitHub repository size and root licensing evidence. All destinations were absent from the initial owner inventory. Pins below are candidate live-head commits resolved from the latest repository commit search; the acquisition validator will independently require exact equality with the live default-branch HEAD before any mirror is written. A rejected pin must be refreshed and reviewed, never bypassed.

| Product category | Upstream source | Destination repository | Branch | GitHub SPDX | Pinned source commit | Why it is included / current status | Acquisition mode | Final status |
|---|---|---|---|---|---|---|
| ERP / accounting / manufacturing / inventory | [frappe/erpnext](https://github.com/frappe/erpnext) | `tpl-business-erpnext` | develop | GPL-3.0 | `e072e76ac452f7cfd9a8688b8e1bc0be9f695f59` | Full Frappe ERP application. Very large upstream (about 2.0 GB GitHub size); root GPL-3.0 copyleft. Documentation is hosted separately and is not part of this source mirror; review its terms independently. Reviewed two-commit fast-forward adding the Yearly timegrain branch to account-balance timeline calculation; no root license changes. README and license.txt match the refreshed pin; two Mergify backport branch tips are being reconciled with preserved history. pending-verification; issue #884; run 43385362354 acquisition step in progress. | mirror | pending-verification |
| Customer support / helpdesk | [zammad/zammad](https://github.com/zammad/zammad) | `tpl-business-zammad` | develop | AGPL-3.0 | `45329c81672830ed87d7a4544a13cfc0e42d8b80` | Full Ruby/Rails helpdesk. AGPL-3.0 network-copyleft; large upstream (about 1.1 GB); audit bundled dependencies and edition boundaries. acquired-and-verified; issue #885; run 43385366767; independent read-only verifier passed; Gemfile exactly matches pinned upstream. | mirror | acquired-and-verified |
| Electronic signatures / document workflows | [documenso/documenso](https://github.com/documenso/documenso) | `tpl-business-documenso` | main | AGPL-3.0 | `1e2333d534e151578ffb05394428e2a7efea5f50` | Full TypeScript e-signature platform. Community Edition is AGPL-3.0; Enterprise Edition is separately commercially licensed. acquired-and-verified; issue #886; run 43385371938; independent read-only verifier passed; package.json exactly matches pinned upstream. | mirror | acquired-and-verified |
| Messaging / event streaming / pub-sub | [nats-io/nats-server](https://github.com/nats-io/nats-server) | `tpl-infra-nats` | main | Apache-2.0 | `79d1d2c1b28c9714c7dfe0f14b52dcab65a2c465` | NATS server and JetStream messaging infrastructure. Apache-2.0; preserve notices and inspect bundled dependencies. acquired-and-verified; issue #887; run 43385378332; independent read-only verifier passed; go.mod exactly matches pinned upstream. | mirror | acquired-and-verified |
| Secrets / encryption / certificate management | [openbao/openbao](https://github.com/openbao/openbao) | `tpl-infra-openbao` | main | MPL-2.0 | `92de51f7a0586759215d299bc79118874ea54fb1` | OpenBao secrets/key management. MPL-2.0 file-level copyleft; retain notices and identify modified MPL-covered files before distribution. acquired-and-verified; issue #888; run 43385383544; independent read-only verifier passed; go.mod exactly matches pinned upstream. | mirror | acquired-and-verified |
| Distributed object storage / S3 compatibility | [seaweedfs/seaweedfs](https://github.com/seaweedfs/seaweedfs) | `tpl-infra-seaweedfs` | master | Apache-2.0 | `a5763986628fa629cb87b58f1b885426cf664d88` | Distributed object/file storage with S3 API. Apache-2.0 root; separately offered Enterprise Edition features are not assumed licensed or present. acquired-and-verified; issue #889; run 43385387118; independent read-only verifier passed; go.mod exactly matches pinned upstream. | mirror | acquired-and-verified |
| API gateway / reverse proxy / ingress | [traefik/traefik](https://github.com/traefik/traefik) | `tpl-infra-traefik` | master | MIT | `b45eeb07b7b15e8b4bb85a7b0ed8a32eaa75c8c9` | Cloud-native reverse proxy, ingress and gateway. MIT; preserve notices and audit plugins/providers and dependencies. acquired-and-verified; issue #890; run 43385391255; independent read-only verifier passed; go.mod exactly matches pinned upstream. | mirror | acquired-and-verified |
| Search / analytics engine | [opensearch-project/OpenSearch](https://github.com/opensearch-project/OpenSearch) | `tpl-infra-opensearch` | main | Apache-2.0 | `a8767707aa8b6db8ab15d8309936b07f6c517ad0` | Distributed search and analytics engine. Apache-2.0 root; inspect plugins, bundled components and notices individually. acquired-and-verified; issue #891; run 43385394906; independent read-only verifier passed; build.gradle exactly matches pinned upstream. | mirror | acquired-and-verified |
| Metrics collection / monitoring | [prometheus/prometheus](https://github.com/prometheus/prometheus) | `tpl-observability-prometheus` | main | Apache-2.0 | `49c815a0ea46c7a6a6b723e4b634c4bf36f7022c` | Prometheus metrics server, TSDB and query engine. Apache-2.0; preserve LICENSE/NOTICE and inspect vendored modules. acquired-and-verified; issue #892; run 43385404100; independent read-only verifier passed; go.mod exactly matches pinned upstream. | mirror | acquired-and-verified |
| Dashboards / visualization | [grafana/grafana](https://github.com/grafana/grafana) | `tpl-observability-grafana` | main | AGPL-3.0 | `2204676d80b342730f748fa651289a915681dad2` | Grafana visualization and alerting platform. GitHub SPDX AGPL-3.0; LICENSING.md declares Apache-2.0 exceptions and vendor directories under original licenses. Source exposes 2,069 raw refs (1,315 heads + 754 tags); the acquisition controller now pushes writable refs in batches of 100 and filters ephemeral merge-queue refs. Destination exists; large mirror push/verification pending. issue #893; refreshed pin 2204676d. | mirror | pending-verification |
| Log aggregation | [grafana/loki](https://github.com/grafana/loki) | `tpl-observability-loki` | main | AGPL-3.0 | `8f83d5672776aeb656fdc0f6fe3f38be3a33e80a` |Loki log aggregation system. AGPL-3.0 root; LICENSING.md lists Apache-2.0 exceptions and vendor directories under original licenses. Source exposes 1,356 raw refs (948 heads + 408 tags); controller pushed in bounded batches. acquired-and-verified; issue #894; workflow run 43389550953; independent read-only verifier passed; go.mod and LICENSE match byte-for-byte.| mirror | acquired-and-verified |
| Distributed tracing backend | [grafana/tempo](https://github.com/grafana/tempo) | `tpl-observability-tempo` | main | AGPL-3.0 | `f023741110df81cd20d014814e01058b3de53787` |Tempo distributed tracing backend. AGPL-3.0 root; LICENSING.md identifies Apache-2.0 exceptions and upstream-licensed directories. Source exposes 314 raw refs. Reviewed two-commit fast-forward: Memcached image digest regeneration and vendored charm.land/lipgloss/v2 update from 2.0.6 to 2.1.0; no license changes. acquired-and-verified; issue #895; workflow run 43390820532; independent read-only verifier passed.| mirror | acquired-and-verified |
| Telemetry collection / routing | [open-telemetry/opentelemetry-collector](https://github.com/open-telemetry/opentelemetry-collector) | `tpl-observability-otel-collector` | main | Apache-2.0 | `4888f0b280f927f9ec356c3d8a9c02a1a37819dc` | OpenTelemetry Collector core pipeline and component framework. Apache-2.0 root; separately audit contributed receivers/exporters and their dependencies. Source exposes 7,454 raw refs (167 heads + 7,287 tags); use 100-ref batch push. Destination exists; acquisition is in progress; issue #896; run 43385420872. | mirror | pending-verification |
| Transactional email delivery | [postalserver/postal](https://github.com/postalserver/postal) | `tpl-platform-postal` | main | MIT | `d96eddbadeda600595d6247486f9ceb8e99cbc15` |Postal mail delivery platform for inbound/outbound email. Root MIT-LICENCE; preserve copyright notices and audit mail transport dependencies. Source exposes 40 writable refs. acquired-and-verified; issue #897; workflow run 43385424474; independent read-only verifier passed; Gemfile and MIT-LICENCE match pinned upstream byte-for-byte.| mirror | acquired-and-verified |
| Feature flags / remote configuration / experimentation | [Flagsmith/flagsmith](https://github.com/Flagsmith/flagsmith) | `tpl-platform-flagsmith` | main | BSD-3-Clause | `e1d64e6f15842f93dc67f30273e50ceb1d14bcc8` |Feature flags, remote config and experimentation. Core platform BSD-3-Clause; some enterprise governance/management capabilities require a separate Flagsmith Enterprise license. Source exposes 1,131 raw refs (544 heads + 587 tags); controller pushed in bounded batches. acquired-and-verified; issue #898; workflow run 43385428023; independent read-only verifier passed; LICENSE.md and Dockerfile match byte-for-byte.| mirror | acquired-and-verified |
| Enterprise identity / SSO / federation reference | [keycloak/keycloak](https://github.com/keycloak/keycloak) | `tpl-platform-keycloak` | main | Apache-2.0 | `11c147887abc3a0ccdcec27f6fd1b4a4811fac12` |Optional enterprise identity reference only. Apache-2.0. Reviewed signed fast-forward fixing a HOTP race condition that could reuse one OTP across concurrent logins, adjusting OTP/recovery/WebAuthn credential providers and adding a 352-line credential-concurrency regression test; no license changes. This does not replace Luth as ULTRST's canonical external-agent OAuth 2.1 / PKCE authorization layer. Destination refs/manifests were previously matched; refreshed pin and independent verification pending; issue #899.| mirror | pending-verification |

**Expansion baseline:** 44 catalog records before this section; 16 additional candidates recorded; 60 catalog records after inclusion. Current evidence at report preparation: 8 of 16 candidates acquired and independently verified; 3 are pending verification/reacquisition; 5 are blocked on GitHub's secondary repository-creation rate limit. This is not a claim of full completion.
