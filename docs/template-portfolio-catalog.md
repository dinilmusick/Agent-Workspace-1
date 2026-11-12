# ULTRST Software Starter Portfolio — Coverage and Acquisition Manifest

Snapshot: 2026-11-12 (UTC)  
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
| RAG / document intelligence | [infiniflow/ragflow](https://github.com/infiniflow/ragflow) | `tpl-ai-ragflow` | main | Apache-2.0 | `1fc73d125f0081dc3090835a96a4e45e13055e84` | Functional document-understanding RAG engine with retrieval and agent capabilities. Dependency/model/asset audit remains separate. |
| Visual AI agent and workflow builder | [langflow-ai/langflow](https://github.com/langflow-ai/langflow) | `tpl-ai-langflow` | main | MIT | `2cf9ce808afa6ad3f41aa5f6b47bdcb1927cde84` | Visual agent, LLM and MCP workflow builder. |
| Self-hosted PaaS / deployment control plane | [dokku/dokku](https://github.com/dokku/dokku) | `tpl-deployment-dokku` | master | MIT | `bf03afb9810caea112f2ea2e203b21da4f84c382` | Self-hosted application deployment platform. Existing audit is CONDITIONAL pending plugin/module and bundled-helper review. |
| Inventory / manufacturing operations | [inventree/InvenTree](https://github.com/inventree/InvenTree) | `tpl-inventory-inventree` | master | MIT | `7e57196d76f4560caebbff9508ea5e230341fc08` | Full inventory and parts-management product. Existing audit found LGPL runtime dependencies; private study only. |
| Healthcare / FHIR platform | [medplum/medplum](https://github.com/medplum/medplum) | `tpl-health-medplum` | main | Apache-2.0 | `e7e7e40191440fca0d06ded9d2b56c11c639058f` | Full healthcare interoperability platform and FHIR server. Existing audit found an unlicensed bundled font; private study only until corrected. |
| Appointment scheduling / booking | [calcom/cal.diy](https://github.com/calcom/cal.diy) | `tpl-booking-caldiy` | main | MIT | `ef7954d16ab50882ca2f263c551537115b8a8bb1` | Active self-hosted appointment-scheduling application. Treat as the community Cal.diy project, not a statement about Cal.com licensing. |
| BI / analytics dashboards | [apache/superset](https://github.com/apache/superset) | `tpl-bi-superset` | master | Apache-2.0 | `58a1a5c7e8f759383573ba15ba509e8d1bc49015` | Mature business-intelligence and data-visualization application. |
| ELT / data integration | [meltano/meltano](https://github.com/meltano/meltano) | `tpl-data-meltano` | main | MIT | `23fab6f99554b0de7ce17d6ede3b8a45bc3234a9` | Declarative, code-first ELT and connector platform. |
| Mobile application starters | [expo/examples](https://github.com/expo/examples) | `tpl-mobile-expo-examples` | master | MIT | `2cc7a440b01eb30e326b91cf1f3aae41e749d128` | Official working examples across Expo / React Native mobile use cases. |
| Desktop application framework (Rust) | [tauri-apps/tauri](https://github.com/tauri-apps/tauri) | `tpl-desktop-tauri` | dev | Apache-2.0 | `5edd31c8a8914674c217b21a660a914823da2dae` | Native desktop/mobile runtime and examples for web-fronted Rust applications. |
| Desktop application starter (Electron) | [electron-react-boilerplate/electron-react-boilerplate](https://github.com/electron-react-boilerplate/electron-react-boilerplate) | `tpl-desktop-electron` | main | MIT | `e5b8242d8b21a4290c3a1f18ae3b64167e9de04a` | Complete Electron + React desktop starter. |
| Browser extensions | [wxt-dev/wxt](https://github.com/wxt-dev/wxt) | `tpl-browser-wxt` | main | MIT | `64439559a7b745157ddbe3be67d3ba13ae3491e1` | Cross-browser extension framework with MV2/MV3, TypeScript, HMR and publishing support. |
| CI/CD platform | [woodpecker-ci/woodpecker](https://github.com/woodpecker-ci/woodpecker) | `tpl-cicd-woodpecker` | main | Apache-2.0 | `913b07ea87bd6999765350838021b0e90726fb01` | Self-hostable CI/CD server and pipeline system. |
| Infrastructure as code | [pulumi/pulumi](https://github.com/pulumi/pulumi) | `tpl-iac-pulumi` | master | Apache-2.0 | `e449c97836dcef7db8d19ba8190f05e512e0c3b1` | Multi-language infrastructure-as-code engine and provider ecosystem. |
| Video conferencing / WebRTC | [jitsi/jitsi-meet](https://github.com/jitsi/jitsi-meet) | `tpl-video-jitsi` | master | Apache-2.0 | `5aa134f10d7ea42998a58d8200b30de6335ef5b1` | Full self-hostable video-meeting product and embeddable meeting UI. |
| Subscription billing / payments | [killbill/killbill](https://github.com/killbill/killbill) | `tpl-billing-killbill` | master | Apache-2.0 | `52e2f55f103baf0703ddee71e10a7036595fc851` | Mature subscription billing and payments platform. |
| Modern project management | [makeplane/plane](https://github.com/makeplane/plane) | `tpl-project-plane` | preview | AGPL-3.0 | `6190932e2bc2b76d4a7ec11ea9040e3a70fc40ad` | Newer complete project-management product to compare with the existing maintenance-mode Kanboard. Pinned default branch is preview. |
| Full community / forum platform | [nodebb/nodebb](https://github.com/NodeBB/NodeBB) | `tpl-community-nodebb` | master | GPL-3.0 | `b04f482eb068e9421bed35c335232164a27fc5b5` | Full Node.js community discussion platform; complements the existing Flarum skeleton. |
| HRMS | [frappe/hrms](https://github.com/frappe/hrms) | `tpl-hrms-frappe` | develop | GPL-3.0 | `acc4b3a70a6ac52ae6de175df22a5855f428d067` | Human-resources application with employee, leave, payroll and related workflows. |
| LMS / education | [moodle/moodle](https://github.com/moodle/moodle) | `tpl-lms-moodle` | main | GPL-3.0 | `afbcc55fa1bd80dcdd887b8965dd8c28c0f3bbda` | Full learning-management platform for courses, users, assessments and learning workflows. |
| Social network / federated publishing | [mastodon/mastodon](https://github.com/mastodon/mastodon) | `tpl-social-mastodon` | main | AGPL-3.0 | `ca8b0ffac86cc5b064a4573f16b8061716c8ab6f` | Complete federated social-network product. |
| Document management / archive | [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) | `tpl-documents-paperless` | dev | GPL-3.0 | `a1d76f3a19c9bf7067491de6f0a12672676ae9f1` | Full document ingestion, OCR, tagging and archive application. |
| Cloud security assessment | [prowler-cloud/prowler](https://github.com/prowler-cloud/prowler) | `tpl-cloud-security-prowler` | master | Apache-2.0 | `f485982d4cf4be87a76c6906f44e42675fec2913` | Multi-cloud security posture assessment and reporting tool. |
| Data workflow orchestration | [apache/airflow](https://github.com/apache/airflow) | `tpl-data-airflow` | main | Apache-2.0 | `e024d4c15a52a843c28aa773c2d5db69fe21deea` | Production-grade DAG-based workflow scheduling and execution; complements Temporal rather than replacing it. |

## 3. Additional reference-only candidates

GitHub did not provide a recognized SPDX license identifier for these exact repository snapshots, or their license contains additional conditions requiring specific review. The private acquisition workflow must create only a README provenance record for these; it must not copy upstream code or assets.

| Product category | Upstream source | Destination reference | Branch | Observed source commit | Reason for reference-only treatment |
|---|---|---|---|---|---|
| Customer support / helpdesk | [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) | `tpl-helpdesk-chatwoot` | develop | `bf541372d1e75d7b65a17169e7057a24e7af44ad` | GitHub API returned NOASSERTION; inspect the complete root and dependency license data before mirroring. |
| IoT / device management | [thingsboard/thingsboard](https://github.com/thingsboard/thingsboard) | `tpl-iot-thingsboard` | master | `aa08e0ae5f6ec015b26cdb4c8e5accb0b668cda1` | GitHub API returned NOASSERTION; root licensing and edition boundaries need manual review. |
| Search service / search engine | [meilisearch/meilisearch](https://github.com/meilisearch/meilisearch) | `tpl-search-meilisearch` | main | `c25aa858ba9caa5a19faf6958f43a170cc0b7ebc` | GitHub API returned NOASSERTION; verify the exact license and edition boundary before mirroring. |
| Event ticketing / event operations | [pretix/pretix](https://github.com/pretix/pretix) | `tpl-events-pretix` | master | `137059dd4e7a7f4643199323b69a85824bffc28e` | License includes special additional terms and service-purpose restrictions; do not mirror automatically. |
| AI product / agentic workflow workspace | [langgenius/dify](https://github.com/langgenius/dify) | `tpl-ai-dify` | main | `b800daffd08a458ec922869a2b08a6dd4b904e06` | Dify Open Source License contains added conditions; use reference-only until reviewed. |
| Automation / app integration | [n8n-io/n8n](https://github.com/n8n-io/n8n) | `tpl-automation-n8n` | master | `f216f7f7c157373c6100bd2d79cef8b1f7565b1d` | Sustainable Use / fair-code terms; reference-only. Existing Node-RED remains the open-source automation starter. |

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
| `tpl-bi-superset` | `58a1a5c7e8f759383573ba15ba509e8d1bc49015` | Superset API metadata handling now skips schema columns absent from explicit Marshmallow schemas; adds regression coverage for unfiltered `_info` endpoints. | Accept pin; Apache-2.0 root metadata unchanged. |
| `tpl-data-meltano` | `23fab6f99554b0de7ce17d6ede3b8a45bc3234a9` | Documentation lockfile updates fast-xml-parser from 5.11.2 to 5.12.0 and its transitive dependency integrity/version records. | Accept pin; MIT root metadata unchanged. |
| `tpl-data-airflow` | `e024d4c15a52a843c28aa773c2d5db69fe21deea` | Corrects the timezone in a TimeSensor unit-test time-machine fixture to explicit UTC. | Accept pin; Apache-2.0 root metadata unchanged. |
| `tpl-iot-thingsboard` | `aa08e0ae5f6ec015b26cdb4c8e5accb0b668cda1` | Merge updates the ThingsBoard AI model processor's Optional access to use the direct value accessor. | Accept pin for reference-only record; GitHub SPDX metadata remains NOASSERTION. |
| `tpl-automation-n8n` | `f216f7f7c157373c6100bd2d79cef8b1f7565b1d` | Replaces two hard-coded editor dismiss-tooltip strings with the localized generic.dismiss translation. | Accept pin for reference-only record; GitHub SPDX metadata remains NOASSERTION. |


A subsequent live-head check found that Spree's default branch advanced after the earlier catalog refresh. The first two acquisition attempts correctly rejected the stale default-branch pin before modifying the destination. The new head was reviewed before refreshing the catalog:

| Destination | Previous pin | Reviewed current source commit | Reviewed change | Decision |
|---|---|---|---|---|
| `tpl-commerce-spree` | `ab8f82fc5d4f91beb42447f84df9106d79e7a39a` | `9af32fb49de0e0c2a7aef41044046e272646fcb9` | Two signed commits: Dependabot updates `peter-evans/create-pull-request` from 8.1.1 to 8.1.2; Spree fixes draft-order line removal so recalculation and status refresh occur after successful removal, rejected removals roll back under nested/order-lock transactions, and API/agent-tool/dashboard regression tests cover the behavior. Seven files changed; no dependency addition or license change identified. | Accept refreshed pin; BSD-3-Clause root metadata unchanged. |

The new Spree head is a two-commit fast-forward from the previous pin. GitHub reports the latest commit signature as verified. The catalog pin now records the reviewed current default-branch HEAD; the acquisition validator will recheck it at request time.


A subsequent live-head review found that RAGFlow's main branch advanced from `292e1717d60a8efcd48f1fa04d03923ac7579540` to `1fc73d125f0081dc3090835a96a4e45e13055e84`. The acquisition request correctly rejected the stale pin. The three-commit fast-forward was reviewed before refreshing the catalog:

| Destination | Previous pin | Reviewed current source commit | Reviewed change | Decision |
|---|---|---|---|---|
| `tpl-ai-ragflow` | `292e1717d60a8efcd48f1fa04d03923ac7579540` | `1fc73d125f0081dc3090835a96a4e45e13055e84` | Three signature-verified commits: two documentation-icon corrections and PR #22241, a 12-file knowledge-compiler performance change (1,368 additions / 228 deletions). The performance work batches document-product reads, adds a compiled-row existence filter, gates debug-only diagnostics, and falls back to bounded per-document reads when a batch would exceed the engine result window. Regression tests cover grouping, deduplication, result-window boundaries and fallback behavior. No dependency manifest or license change identified; root license remains Apache-2.0. Upstream PR reports the targeted unit/full unit tier green; integration tests were not run because its Elasticsearch/MySQL service stack was unavailable. | Accept refreshed pin for private research mirror; preserve the integration-test limitation for later workspace verification. |

GitHub compare confirms the previous pin is an ancestor of the new main HEAD (three commits ahead, zero behind). All three commit signatures are verified. The acquisition validator will recheck the exact new HEAD at request time.

The acquisition validator requires each requested source, destination and exact commit to occur together in this catalog and independently requires that commit to equal the live default-branch HEAD at request time. A later branch movement therefore rejects acquisition until this catalog is refreshed and reviewed again.


### Agent 07 — collaboration and organizational software pin review — 2026-11-12

The six assigned repositories were rechecked against their live upstream default branches and GitHub SPDX metadata. Four pins were already exact. Two fast-forwarded upstream heads were reviewed commit-by-commit before updating the catalog:

| Destination | Default branch | Previous pin | Reviewed current HEAD | Compare | Review |
|---|---|---|---|---|---|
| `tpl-video-jitsi` | `master` | `224092bbd7050b0a031692d10cdfd486758c2539` | `5aa134f10d7ea42998a58d8200b30de6335ef5b1` | [3 commits ahead, 0 behind](https://github.com/jitsi/jitsi-meet/compare/224092bbd7050b0a031692d10cdfd486758c2539...5aa134f10d7ea42998a58d8200b30de6335ef5b1) | Two test-only changes improve visitor chat/poll/promotion coverage and synchronize breakout-room membership before chat assertions; one Catalan translation update. Four files; no dependency/lockfile, production API/backend, migration or root-license change. Two test commits have unverified signatures; the final locale commit is verified. |
| `tpl-social-mastodon` | `main` | `b31c484d97c9b7f109ecdcc3de140ac2e865fd4d` | `ca8b0ffac86cc5b064a4573f16b8061716c8ab6f` | [6 commits ahead, 0 behind](https://github.com/mastodon/mastodon/compare/b31c484d97c9b7f109ecdcc3de140ac2e865fd4d...ca8b0ffac86cc5b064a4573f16b8061716c8ab6f) | Frontend accessibility/media/button/icon refinements, emoji text-field handling, translations and alert deduplication with a reducer regression test. 43 files; no dependency/lockfile, backend/API, migration or root-license change. All six commit signatures are verified. |

The remaining four pins were independently confirmed at the live default-branch HEAD on 2026-11-12: `makeplane/plane` (`preview`, `6190932e2bc2b76d4a7ec11ea9040e3a70fc40ad`), `NodeBB/NodeBB` (`master`, `b04f482eb068e9421bed35c335232164a27fc5b5`), `frappe/hrms` (`develop`, `acc4b3a70a6ac52ae6de175df22a5855f428d067`) and `moodle/moodle` (`main`, `afbcc55fa1bd80dcdd887b8965dd8c28c0f3bbda`). GitHub SPDX metadata matched catalog identifiers for all six: Apache-2.0, AGPL-3.0, GPL-3.0, GPL-3.0, GPL-3.0 and AGPL-3.0 respectively.

Legal-file inspection confirmed Jitsi's root Apache-2.0 license and Debian copyright notice (including a historical MIT attribution); Plane's AGPL-3.0 license, `COPYRIGHT.txt` and mandatory source-header policy; NodeBB's GPL-3.0 `LICENSE`; Frappe HRMS's GPL-3.0 `license.txt`; Moodle's GPL-3.0 `COPYING.txt` plus numerous bundled third-party license/NOTICE files; and Mastodon's AGPL-3.0 `LICENSE`, `AUTHORS.md` and separate font/icon/image license files. Preserve all such files verbatim. Moodle's recursive legal-file listing was truncated, and no complete transitive dependency-license audit was performed. These projects remain **PRIVATE-STUDY-MIRROR only**; no commercial reuse, distribution, deployment or feature/security/build approval is granted by this pin review.

