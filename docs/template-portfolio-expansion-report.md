# ULTRST Template Portfolio Expansion & Verification Report

**Control repository:** `dinilmusick/Agent-Workspace-1`  
**Canonical catalog:** [docs/template-portfolio-catalog.md](template-portfolio-catalog.md)  
**Acquisition workflow:** [independent-commercial-acquisition.yml](../.github/workflows/independent-commercial-acquisition.yml)  
**Snapshot:** 2026-11-13  
**Report state:** In progress — this report intentionally distinguishes completed verification from pending and rate-limited work.

## 1. Executive status

The catalog has been extended from **44 to 60 records**: 45 full-source mirror candidates and six reference-only records, plus the nine foundational portfolio records. The 16 requested additions are all represented in the canonical catalog.

At this snapshot:

- **10/16** new candidates have passed the canonical acquisition workflow and independent read-only verification.
- **15/16** requested destination repositories currently exist and are private; existence is not treated as source verification.
- **1/16** destination is not yet present.
- Airflow has been refreshed to the reviewed current upstream pin and independently verified.
- Five destination-creation attempts encountered GitHub's secondary content-creation rate limit. The controller now staggers repository creation and uses exponential backoff.
- Large upstreams with thousands of refs require bounded ref pushes. The acquisition controller now pushes refs in batches of 100 and preserves/deletes old refs only after archiving their tips.

No project is described as commercially cleared. Private research mirroring is not commercial-use permission.

## 2. Sixteen-candidate verification matrix

| # | Project | Upstream | Destination | Acquisition mode | License review | Source verified | Final status |
|---:|---|---|---|---|---|---|---|
| 1 | ERPNext | [frappe/erpnext](https://github.com/frappe/erpnext) — `develop`, `e072e76ac452f7cfd9a8688b8e1bc0be9f695f59` | [tpl-business-erpnext](https://github.com/dinilmusick/tpl-business-erpnext) | mirror | GPL-3.0; documentation is hosted separately and needs its own review | README and `license.txt` match; two Mergify backport branch tips are being reconciled with preserved history | pending-verification |
| 2 | Zammad | [zammad/zammad](https://github.com/zammad/zammad) — `develop`, `45329c81672830ed87d7a4544a13cfc0e42d8b80` | [tpl-business-zammad](https://github.com/dinilmusick/tpl-business-zammad) | mirror | AGPL-3.0; review network-copyleft obligations and any separately licensed edition components | Yes — independent verifier passed; `Gemfile` matches pinned upstream | acquired-and-verified |
| 3 | Documenso | [documenso/documenso](https://github.com/documenso/documenso) — `main`, `1e2333d534e151578ffb05394428e2a7efea5f50` | [tpl-business-documenso](https://github.com/dinilmusick/tpl-business-documenso) | mirror | AGPL-3.0 Community Edition; Enterprise Edition is separately commercially licensed | Yes — independent verifier passed; `package.json` matches pinned upstream | acquired-and-verified |
| 4 | NATS Server | [nats-io/nats-server](https://github.com/nats-io/nats-server) — `main`, `79d1d2c1b28c9714c7dfe0f14b52dcab65a2c465` | [tpl-infra-nats](https://github.com/dinilmusick/tpl-infra-nats) | mirror | Apache-2.0; retain notices and audit bundled dependencies | Yes — independent verifier passed; `go.mod` matches pinned upstream | acquired-and-verified |
| 5 | OpenBao | [openbao/openbao](https://github.com/openbao/openbao) — `main`, `92de51f7a0586759215d299bc79118874ea54fb1` | [tpl-infra-openbao](https://github.com/dinilmusick/tpl-infra-openbao) | mirror | MPL-2.0 file-level copyleft; retain notices for covered files | Yes — independent verifier passed; `go.mod` matches pinned upstream | acquired-and-verified |
| 6 | SeaweedFS | [seaweedfs/seaweedfs](https://github.com/seaweedfs/seaweedfs) — `master`, `a5763986628fa629cb87b58f1b885426cf664d88` | [tpl-infra-seaweedfs](https://github.com/dinilmusick/tpl-infra-seaweedfs) | mirror | Apache-2.0 root; separately offered Enterprise features are not presumed included | Yes — independent verifier passed; `go.mod` matches pinned upstream | acquired-and-verified |
| 7 | Traefik | [traefik/traefik](https://github.com/traefik/traefik) — `master`, `b45eeb07b7b15e8b4bb85a7b0ed8a32eaa75c8c9` | [tpl-infra-traefik](https://github.com/dinilmusick/tpl-infra-traefik) | mirror | MIT; preserve notices and audit providers/plugins | Yes — independent verifier passed; `go.mod` matches pinned upstream | acquired-and-verified |
| 8 | OpenSearch | [opensearch-project/OpenSearch](https://github.com/opensearch-project/OpenSearch) — `main`, `a8767707aa8b6db8ab15d8309936b07f6c517ad0` | [tpl-infra-opensearch](https://github.com/dinilmusick/tpl-infra-opensearch) | mirror | Apache-2.0 root; review plugin and bundled-component notices individually | Yes — independent verifier passed; `build.gradle` matches pinned upstream | acquired-and-verified |
| 9 | Prometheus | [prometheus/prometheus](https://github.com/prometheus/prometheus) — `main`, `49c815a0ea46c7a6a6b723e4b634c4bf36f7022c` | [tpl-observability-prometheus](https://github.com/dinilmusick/tpl-observability-prometheus) | mirror | Apache-2.0; preserve LICENSE/NOTICE and vendored notices | Yes — independent verifier passed; `go.mod` matches pinned upstream | acquired-and-verified |
| 10 | Grafana | [grafana/grafana](https://github.com/grafana/grafana) — `main`, `2204676d80b342730f748fa651289a915681dad2` | [tpl-observability-grafana](https://github.com/dinilmusick/tpl-observability-grafana) | mirror | AGPL-3.0; `LICENSING.md` declares Apache-2.0 exceptions and original vendor licenses | Not yet — destination exists; 2,069 raw refs require bounded pushes; verification pending | pending-verification |
| 11 | Loki | [grafana/loki](https://github.com/grafana/loki) — `main`, `8f83d5672776aeb656fdc0f6fe3f38be3a33e80a` | [tpl-observability-loki](https://github.com/dinilmusick/tpl-observability-loki) | mirror | AGPL-3.0; `LICENSING.md` lists Apache-2.0 exceptions and vendor directories under original licenses | Source refs match after excluding ephemeral merge-queue refs; `go.mod` and `LICENSE` match; independent verifier running | pending-verification |
| 12 | Tempo | [grafana/tempo](https://github.com/grafana/tempo) — `main`, `f023741110df81cd20d014814e01058b3de53787` | [tpl-observability-tempo](https://github.com/dinilmusick/tpl-observability-tempo) | mirror | AGPL-3.0; `LICENSING.md` identifies Apache-2.0 exceptions and upstream-licensed directories | No — reviewed two-commit fast-forward and refreshed pin; destination creation/acquisition pending | pending-verification |
| 13 | OpenTelemetry Collector | [open-telemetry/opentelemetry-collector](https://github.com/open-telemetry/opentelemetry-collector) — `main`, `4888f0b280f927f9ec356c3d8a9c02a1a37819dc` | [tpl-observability-otel-collector](https://github.com/dinilmusick/tpl-observability-otel-collector) | mirror | Apache-2.0 root; contributed receivers/exporters in separate projects need separate review | Destination exists; 7,454 raw refs are being pushed in bounded batches | pending-verification |
| 14 | Postal | [postalserver/postal](https://github.com/postalserver/postal) — `main`, `d96eddbadeda600595d6247486f9ceb8e99cbc15` | [tpl-platform-postal](https://github.com/dinilmusick/tpl-platform-postal) | mirror | MIT; preserve the upstream MIT-LICENCE and third-party notices | Yes — independent verifier passed; `Gemfile` and `MIT-LICENCE` match byte-for-byte | acquired-and-verified |
| 15 | Flagsmith | [Flagsmith/flagsmith](https://github.com/Flagsmith/flagsmith) — `main`, `e1d64e6f15842f93dc67f30273e50ceb1d14bcc8` | [tpl-platform-flagsmith](https://github.com/dinilmusick/tpl-platform-flagsmith) | mirror | BSD-3-Clause core; some enterprise governance/management capabilities require separate commercial licensing | Yes — independent verifier passed; `LICENSE.md` and `Dockerfile` match byte-for-byte | acquired-and-verified |
| 16 | Keycloak | [keycloak/keycloak](https://github.com/keycloak/keycloak) — `main`, `11c147887abc3a0ccdcec27f6fd1b4a4811fac12` | [tpl-platform-keycloak](https://github.com/dinilmusick/tpl-platform-keycloak) | mirror | Apache-2.0; identity reference only, not an alternative ULTRST auth authority | Reviewed HOTP concurrency security fix and regression test; refreshed acquisition/verifier pending | pending-verification |

### Candidate issue and workflow evidence

| Candidate | Acquisition issue | Workflow evidence |
|---|---|---|
| ERPNext | [#884](https://github.com/dinilmusick/Agent-Workspace-1/issues/884) | [Original run](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385362354); refreshed pin is now in the live issue body for safe retry |
| Zammad | [#885](https://github.com/dinilmusick/Agent-Workspace-1/issues/885) | [43385366767](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385366767) |
| Documenso | [#886](https://github.com/dinilmusick/Agent-Workspace-1/issues/886) | [43385371938](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385371938) |
| NATS | [#887](https://github.com/dinilmusick/Agent-Workspace-1/issues/887) | [43385378332](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385378332) |
| OpenBao | [#888](https://github.com/dinilmusick/Agent-Workspace-1/issues/888) | [43385383544](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385383544) |
| SeaweedFS | [#889](https://github.com/dinilmusick/Agent-Workspace-1/issues/889) | [43385387118](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385387118) |
| Traefik | [#890](https://github.com/dinilmusick/Agent-Workspace-1/issues/890) | [43385391255](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385391255) |
| OpenSearch | [#891](https://github.com/dinilmusick/Agent-Workspace-1/issues/891) | [43385394906](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385394906) |
| Prometheus | [#892](https://github.com/dinilmusick/Agent-Workspace-1/issues/892) | [43385404100](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385404100) |
| Grafana | [#893](https://github.com/dinilmusick/Agent-Workspace-1/issues/893) | [Original run](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385408704); current issue body refreshed to the reviewed live HEAD |
| Loki | [#894](https://github.com/dinilmusick/Agent-Workspace-1/issues/894) | [Original run](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385410792); current issue body refreshed to the reviewed live HEAD |
| Tempo | [#895](https://github.com/dinilmusick/Agent-Workspace-1/issues/895) | [43385416895](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385416895) |
| OpenTelemetry Collector | [#896](https://github.com/dinilmusick/Agent-Workspace-1/issues/896) | [43385420872](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385420872) |
| Postal | [#897](https://github.com/dinilmusick/Agent-Workspace-1/issues/897) (closed) | [43385424474](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385424474) — success |
| Flagsmith | [#898](https://github.com/dinilmusick/Agent-Workspace-1/issues/898) (closed) | [43385428023](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385428023) — success |
| Keycloak | [#899](https://github.com/dinilmusick/Agent-Workspace-1/issues/899) | [43385432594](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385432594); issue body refreshed to reviewed HOTP security-fix HEAD |

## 3. Existing portfolio integrity

| Measure | Before expansion | Current snapshot |
|---|---:|---:|
| Canonical catalog records | 44 | 60 |
| Indexed private `tpl-*` repositories | 44 | 59 |
| New requested destinations currently present | 0 | 15 of 16 |
| New candidates independently verified | 0 | 10 of 16 |
| Reference-only records added by this expansion | 0 | 0 |
| Duplicate destination repositories created | 0 | 0 |

All 59 currently indexed `tpl-*` repositories are private. The 44 pre-existing destinations were preserved. The only absent destination at this snapshot is Tempo. Empty repositories and repositories with only a subset of refs are not counted as verified acquisitions.

A single unrelated open pull request remains in the control repository; no expansion change was merged through or discarded from that PR.

## 4. Airflow resolution

**Upstream:** [apache/airflow](https://github.com/apache/airflow)  
**Destination:** [tpl-data-airflow](https://github.com/dinilmusick/tpl-data-airflow)  
**Reviewed branch/pin:** `main` / `ea7677ed17271db01fa5ce83d708b2c58c88984b`  
**Final status:** **acquired-and-verified**

The original issue [#809](https://github.com/dinilmusick/Agent-Workspace-1/issues/809) and run [43370198149](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43370198149) had acquired source but failed independent verification after upstream moved. The seven-commit fast-forward was reviewed, including Beam/Dataflow job-ID discovery and async process handling, Microsoft Graph operators/sensors/triggers and tests, language SDK documentation and CI image checks. The refreshed request [#900](https://github.com/dinilmusick/Agent-Workspace-1/issues/900) completed successfully in [run 43385480697](https://github.com/dinilmusick/Agent-Workspace-1/actions/runs/43385480697). The independent read-only verifier passed; the destination root `pyproject.toml` matches the pinned upstream file. Issues #809 and #900 are closed as completed.

## 5. Licensing and commercial-use review

- **Copyleft / network-copyleft:** ERPNext (GPL-3.0); Zammad, Documenso, Grafana, Loki and Tempo (AGPL-3.0); OpenBao (MPL-2.0). Preserve notices and assess obligations before distributing modified versions or offering modified network services.
- **Permissive licenses:** NATS, SeaweedFS, OpenSearch, Prometheus, OpenTelemetry Collector and Keycloak (Apache-2.0); Traefik and Postal (MIT); Flagsmith (BSD-3-Clause). Permissive does not remove attribution, NOTICE or third-party license obligations.
- **Separate commercial/enterprise boundaries:** Documenso Enterprise Edition; Flagsmith Enterprise governance/management capabilities; Grafana Enterprise capabilities/plugins; and separately offered SeaweedFS enterprise features. Do not assume they are included in the community source mirror.
- **Nested/vendor exceptions:** Grafana, Loki and Tempo each publish `LICENSING.md` with Apache-2.0 exceptions and vendor directories retaining original licenses. Review those directories individually.
- **Component boundaries:** OpenTelemetry Collector core is not the separate contrib repository; do not assume contrib receivers/exporters are covered by this acquisition.
- **Documentation boundary:** ERPNext documentation is hosted separately and is not part of the source mirror; review its terms independently.
- **No commercial clearance:** All acquisitions are private research mirrors. Private ownership does not confer commercial rights, and no project is marked commercially cleared.

## 6. Portfolio coverage

| Area | Current portfolio coverage |
|---|---|
| Web foundations and backend APIs | Next.js, FastAPI, Refine and related starters |
| Frontend frameworks and UI | Refine, WXT, Expo, Tauri and Electron |
| CMS and publishing | Payload, Hugo, Docusaurus and BookStack |
| Booking and scheduling | Cal.com and Pretix |
| CRM and ERP | Krayin, OFBiz, Frappe HRMS, ERPNext and related business starters |
| Commerce, billing and payments | Spree, Kill Bill and commerce starters |
| Collaboration and organizational software | Kanboard, Plane, Flarum, NodeBB, Jitsi, Moodle and related projects |
| Customer support and helpdesk | Chatwoot and Zammad |
| Documents, signatures and productivity | Paperless and Documenso |
| Messaging and event-driven infrastructure | NATS, Node-RED, n8n and Temporal |
| Object and file storage | SeaweedFS and the existing Kloks storage boundary |
| Search and indexing | Meilisearch and OpenSearch |
| API gateway and networking | Traefik |
| Identity and access management | Luth remains canonical; Keycloak is an additional enterprise reference |
| Secrets and cryptographic infrastructure | OpenBao |
| Metrics, logs and tracing | Prometheus, Grafana, Loki and Tempo; OpenTelemetry Collector provides telemetry routing |
| Email delivery | Postal |
| Feature management and experimentation | Flagsmith |
| Automation and workflow execution | Temporal, Airflow, Node-RED and n8n |
| AI application and agent infrastructure | RAGFlow, Langflow, Dify and related starters |

No additional acquisitions beyond the 16 requested candidates have been authorized. Remaining architectural gaps, if identified in deeper application-level reviews, must be catalogued as proposals rather than acquired without approval.

## 7. Architecture boundaries

- Supabase remains the canonical backend and execution ledger.
- Luth remains the canonical external-agent OAuth 2.1 and PKCE authorization layer.
- Kloks remains the canonical Google Drive/storage backend.
- Keycloak is a reference starter only; it does not replace Luth.
- The new infrastructure projects are independent portfolio starters, not competing central ULTRST control planes.

## 8. Controller changes and verification method

The existing acquisition workflow remains the only acquisition path. The following safeguards were added to address observed failures:

1. Unit tests now cover the expanded catalog, live issue-body resolution on retries, deterministic repository-creation staggering, secondary-rate-limit retries, bounded ref batches and safe archived-ref deletion.
2. The workflow can be retriggered from issue open/edit/reopen events; reruns resolve the current issue body using the issue number in the Actions event payload, so refreshed pins are not trapped in an old event body.
3. Repository creation is deterministically staggered by target name. Secondary-rate-limit retries respect `Retry-After` and use exponential backoff up to the workflow's 120-minute timeout.
4. Full-source refs are pushed in batches of 100. The default branch is pushed first. Before pushing, unexpected destination refs cause a hard stop; old destination refs removed upstream are deleted only after their tips have been preserved under `refs/ultrst-archive`.
5. The independent verifier remains read-only and checks privacy, non-fork status, default branch, writable refs, reachable Git objects and history.

Representative source/destination manifest comparisons have passed for all eight verified candidates and Airflow. No full application build or deployment has been claimed; these acquisitions are source mirrors, and runtime/build readiness requires separate application-specific CI.

## 9. Remaining work at this snapshot

- Complete refreshed ERPNext and Grafana verification, plus the Loki, Tempo, OpenTelemetry Collector and Keycloak verifier runs.
- Complete the remaining Tempo destination creation and all pending verifier runs.
- Independently verify all 16 destination repositories, including complete ref/object coverage and representative project manifests.
- Update the matrix and catalog with final workflow evidence.
- Close superseded retry issues #902 and #908 after their canonical issues #899 and #884 complete.
- Close all completed acquisition issues; leave only genuinely blocked work open with explicit evidence.
- Reconcile the final portfolio coverage and task ledger status.

**Do not interpret this in-progress report as a completion certificate.**
