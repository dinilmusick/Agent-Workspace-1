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
| E-commerce + multi-vendor marketplace | [spree/spree](https://github.com/spree/spree) | `tpl-commerce-spree` | main | BSD-3-Clause | `ab8f82fc5d4f91beb42447f84df9106d79e7a39a` | REST API, TypeScript SDK, storefront and marketplace / B2B use cases in one source project. |
| CRM / sales pipeline | [krayin/laravel-crm](https://github.com/krayin/laravel-crm) | `tpl-crm-krayin` | 2.2 | MIT | `ed6deebfcb8c616eaf352c893a10a6d8e666fc6e` | Complete Laravel CRM. Existing audit rejected the exact dependency set for commercial reuse; private study only. |
| ERP / business operations | [apache/ofbiz-framework](https://github.com/apache/ofbiz-framework) | `tpl-erp-ofbiz` | trunk | Apache-2.0 | `59b32bdc3bed4abdeb9b5eaa12f5d605a3926985` | Broad Java ERP / commerce / order and business-process system. Full dependency and bundled-JAR audit remains required. |
| Python full-stack API application | [fastapi/full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template) | `tpl-backend-fastapi` | master | MIT | `aabb90126964a164e02aff39e7c385bb0598236d` | Complete API + database + frontend starter. Existing audit rejected the current lockfile graph for commercial reuse; private study only. |
| RAG / document intelligence | [infiniflow/ragflow](https://github.com/infiniflow/ragflow) | `tpl-ai-ragflow` | main | Apache-2.0 | `292e1717d60a8efcd48f1fa04d03923ac7579540` | Functional document-understanding RAG engine with retrieval and agent capabilities. Dependency/model/asset audit remains separate. |
| Visual AI agent and workflow builder | [langflow-ai/langflow](https://github.com/langflow-ai/langflow) | `tpl-ai-langflow` | main | MIT | `2cf9ce808afa6ad3f41aa5f6b47bdcb1927cde84` | Visual agent, LLM and MCP workflow builder. |
| Self-hosted PaaS / deployment control plane | [dokku/dokku](https://github.com/dokku/dokku) | `tpl-deployment-dokku` | master | MIT | `bf03afb9810caea112f2ea2e203b21da4f84c382` | Self-hosted application deployment platform. Existing audit is CONDITIONAL pending plugin/module and bundled-helper review. |
| Inventory / manufacturing operations | [inventree/InvenTree](https://github.com/inventree/InvenTree) | `tpl-inventory-inventree` | master | MIT | `7e57196d76f4560caebbff9508ea5e230341fc08` | Full inventory and parts-management product. Existing audit found LGPL runtime dependencies; private study only. |
| Healthcare / FHIR platform | [medplum/medplum](https://github.com/medplum/medplum) | `tpl-health-medplum` | main | Apache-2.0 | `e7e7e40191440fca0d06ded9d2b56c11c639058f` | Full healthcare interoperability platform and FHIR server. Existing audit found an unlicensed bundled font; private study only until corrected. |
| Appointment scheduling / booking | [calcom/cal.diy](https://github.com/calcom/cal.diy) | `tpl-booking-caldiy` | main | MIT | `ef7954d16ab50882ca2f263c551537115b8a8bb1` | Active self-hosted appointment-scheduling application. Treat as the community Cal.diy project, not a statement about Cal.com licensing. |
| BI / analytics dashboards | [apache/superset](https://github.com/apache/superset) | `tpl-bi-superset` | master | Apache-2.0 | `deee513dab356e05104a3e5d4e6bace8be2681ca` | Mature business-intelligence and data-visualization application. |
| ELT / data integration | [meltano/meltano](https://github.com/meltano/meltano) | `tpl-data-meltano` | main | MIT | `a2872768422ad20063304fadb645502757ff14f0` | Declarative, code-first ELT and connector platform. |
| Mobile application starters | [expo/examples](https://github.com/expo/examples) | `tpl-mobile-expo-examples` | master | MIT | `2cc7a440b01eb30e326b91cf1f3aae41e749d128` | Official working examples across Expo / React Native mobile use cases. |
| Desktop application framework (Rust) | [tauri-apps/tauri](https://github.com/tauri-apps/tauri) | `tpl-desktop-tauri` | dev | Apache-2.0 | `b0bd849c2c2581bfdb9edc774fe86219cc7296a8` | Native desktop/mobile runtime and examples for web-fronted Rust applications. |
| Desktop application starter (Electron) | [electron-react-boilerplate/electron-react-boilerplate](https://github.com/electron-react-boilerplate/electron-react-boilerplate) | `tpl-desktop-electron` | main | MIT | `e5b8242d8b21a4290c3a1f18ae3b64167e9de04a` | Complete Electron + React desktop starter. |
| Browser extensions | [wxt-dev/wxt](https://github.com/wxt-dev/wxt) | `tpl-browser-wxt` | main | MIT | `64439559a7b745157ddbe3be67d3ba13ae3491e1` | Cross-browser extension framework with MV2/MV3, TypeScript, HMR and publishing support. |
| CI/CD platform | [woodpecker-ci/woodpecker](https://github.com/woodpecker-ci/woodpecker) | `tpl-cicd-woodpecker` | main | Apache-2.0 | `913b07ea87bd6999765350838021b0e90726fb01` | Self-hostable CI/CD server and pipeline system. |
| Infrastructure as code | [pulumi/pulumi](https://github.com/pulumi/pulumi) | `tpl-iac-pulumi` | master | Apache-2.0 | `e449c97836dcef7db8d19ba8190f05e512e0c3b1` | Multi-language infrastructure-as-code engine and provider ecosystem. |
| Video conferencing / WebRTC | [jitsi/jitsi-meet](https://github.com/jitsi/jitsi-meet) | `tpl-video-jitsi` | master | Apache-2.0 | `224092bbd7050b0a031692d10cdfd486758c2539` | Full self-hostable video-meeting product and embeddable meeting UI. |
| Subscription billing / payments | [killbill/killbill](https://github.com/killbill/killbill) | `tpl-billing-killbill` | master | Apache-2.0 | `52e2f55f103baf0703ddee71e10a7036595fc851` | Mature subscription billing and payments platform. |
| Modern project management | [makeplane/plane](https://github.com/makeplane/plane) | `tpl-project-plane` | preview | AGPL-3.0 | `6190932e2bc2b76d4a7ec11ea9040e3a70fc40ad` | Newer complete project-management product to compare with the existing maintenance-mode Kanboard. Pinned default branch is preview. |
| Full community / forum platform | [nodebb/nodebb](https://github.com/NodeBB/NodeBB) | `tpl-community-nodebb` | master | GPL-3.0 | `b04f482eb068e9421bed35c335232164a27fc5b5` | Full Node.js community discussion platform; complements the existing Flarum skeleton. |
| HRMS | [frappe/hrms](https://github.com/frappe/hrms) | `tpl-hrms-frappe` | develop | GPL-3.0 | `acc4b3a70a6ac52ae6de175df22a5855f428d067` | Human-resources application with employee, leave, payroll and related workflows. |
| LMS / education | [moodle/moodle](https://github.com/moodle/moodle) | `tpl-lms-moodle` | main | GPL-3.0 | `afbcc55fa1bd80dcdd887b8965dd8c28c0f3bbda` | Full learning-management platform for courses, users, assessments and learning workflows. |
| Social network / federated publishing | [mastodon/mastodon](https://github.com/mastodon/mastodon) | `tpl-social-mastodon` | main | AGPL-3.0 | `b31c484d97c9b7f109ecdcc3de140ac2e865fd4d` | Complete federated social-network product. |
| Document management / archive | [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) | `tpl-documents-paperless` | dev | GPL-3.0 | `a1d76f3a19c9bf7067491de6f0a12672676ae9f1` | Full document ingestion, OCR, tagging and archive application. |
| Cloud security assessment | [prowler-cloud/prowler](https://github.com/prowler-cloud/prowler) | `tpl-cloud-security-prowler` | master | Apache-2.0 | `f485982d4cf4be87a76c6906f44e42675fec2913` | Multi-cloud security posture assessment and reporting tool. |
| Data workflow orchestration | [apache/airflow](https://github.com/apache/airflow) | `tpl-data-airflow` | main | Apache-2.0 | `020428773e7b6ef38ed98527ecc1669e5fa500e2` | Production-grade DAG-based workflow scheduling and execution; complements Temporal rather than replacing it. |

## 3. Additional reference-only candidates

GitHub did not provide a recognized SPDX license identifier for these exact repository snapshots, or their license contains additional conditions requiring specific review. The private acquisition workflow must create only a README provenance record for these; it must not copy upstream code or assets.

| Product category | Upstream source | Destination reference | Branch | Observed source commit | Reason for reference-only treatment |
|---|---|---|---|---|---|
| Customer support / helpdesk | [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) | `tpl-helpdesk-chatwoot` | develop | `bf541372d1e75d7b65a17169e7057a24e7af44ad` | GitHub API returned NOASSERTION; inspect the complete root and dependency license data before mirroring. |
| IoT / device management | [thingsboard/thingsboard](https://github.com/thingsboard/thingsboard) | `tpl-iot-thingsboard` | master | `96dad8f89d4858cfb7da565988ce8870e6c2b925` | GitHub API returned NOASSERTION; root licensing and edition boundaries need manual review. |
| Search service / search engine | [meilisearch/meilisearch](https://github.com/meilisearch/meilisearch) | `tpl-search-meilisearch` | main | `4ef8a91f27ee6affff3f59bc46a9e07a2a761636` | GitHub API returned NOASSERTION; verify the exact license and edition boundary before mirroring. |
| Event ticketing / event operations | [pretix/pretix](https://github.com/pretix/pretix) | `tpl-events-pretix` | master | `137059dd4e7a7f4643199323b69a85824bffc28e` | License includes special additional terms and service-purpose restrictions; do not mirror automatically. |
| AI product / agentic workflow workspace | [langgenius/dify](https://github.com/langgenius/dify) | `tpl-ai-dify` | main | `a42dfcf4f99920742222cfaaca7fc696ed6f429a` | Dify Open Source License contains added conditions; use reference-only until reviewed. |
| Automation / app integration | [n8n-io/n8n](https://github.com/n8n-io/n8n) | `tpl-automation-n8n` | master | `85015727cdb719898b93efb752a23f02acaf4ece` | Sustainable Use / fair-code terms; reference-only. Existing Node-RED remains the open-source automation starter. |

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
