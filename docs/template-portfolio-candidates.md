# Template Portfolio — Initial Candidate Audit

Snapshot date: 2026-11-12 (UTC)
Policy: [Commercial Repository Acquisition Policy](commercial-acquisition-policy.md)

This register captures the first ten priority candidates. It is **not a legal clearance or acquisition approval**. Every candidate remains CONDITIONAL until dependency, bundled-asset, font, icon, model, extension, and trademark checks are complete for the exact source revision. No candidate in this register is currently authorized for cloning.

## Candidate register

| Category | Source | Destination | Default branch | Root SPDX | Root license file | Exact source commit | Status |
|---|---|---|---|---|---|---|---|
| CMS | [payloadcms/payload](https://github.com/payloadcms/payload) | `tpl-cms-payload` | `main` | MIT | `LICENSE.md` | `fd82d9dd0321dac0f15efe1474be4e923ecef750` | CONDITIONAL |
| E-commerce | [bagisto/bagisto](https://github.com/bagisto/bagisto) | `tpl-commerce-bagisto` | `2.5` | MIT | `LICENSE` | `add2920a8ecdb8e892b9abeec31520a62c2090e8` | CONDITIONAL |
| CRM | [krayin/laravel-crm](https://github.com/krayin/laravel-crm) | `tpl-crm-krayin` | `2.2` | MIT | `LICENSE` | `ed6deebfcb8c616eaf352c893a10a6d8e666fc6e` | CONDITIONAL |
| ERP | [aureuserp/aureuserp](https://github.com/aureuserp/aureuserp) | `tpl-erp-aureuserp` | `master` | MIT | `LICENSE` | `c31a0db21e00fa436c4949eb4f60ceef81e116ec` | CONDITIONAL |
| Python API starter | [fastapi/full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template) | `tpl-backend-fastapi` | `master` | MIT | `LICENSE` | `aabb90126964a164e02aff39e7c385bb0598236d` | CONDITIONAL |
| RAG | [arc53/DocsGPT](https://github.com/arc53/DocsGPT) | `tpl-ai-docsgpt` | `main` | MIT | `LICENSE` | `d1506d977d0c2036a07e7b464fa05479fab8d973` | CONDITIONAL |
| AI workspace | [Mintplex-Labs/anything-llm](https://github.com/Mintplex-Labs/anything-llm) | `tpl-ai-anythingllm` | `master` | MIT | `LICENSE` | `e8434c07c3d385411aec28e8f9758dfd073565ec` | CONDITIONAL |
| Self-hosted PaaS | [coollabsio/coolify](https://github.com/coollabsio/coolify) | `tpl-deployment-coolify` | `main` | Apache-2.0 | `LICENSE` | `d9ab3d1e8bea98215ed19a27f2f4ac1abd2fa40f` | CONDITIONAL |
| Inventory | [inventree/InvenTree](https://github.com/inventree/InvenTree) | `tpl-inventory-inventree` | `master` | MIT | `LICENSE` | `16309370ba0e4b4a088516ae06c0a681e5315348` | CONDITIONAL |
| Healthcare platform | [medplum/medplum](https://github.com/medplum/medplum) | `tpl-health-medplum` | `main` | Apache-2.0 | `LICENSE.txt` | `cfd9d414ce458eb802f36d41318c7dc031b511a3` | CONDITIONAL |

## Evidence and outstanding checks

### Payload CMS
- GitHub repository metadata reports MIT; the root `LICENSE.md` grants commercial use, modification, distribution and sale subject to retaining notices.
- Recursive tree inspection found many package-level license files. Sampled `packages/payload-cloud`, `packages/payload`, `packages/plugin-ecommerce`, `packages/plugin-stripe` and `packages/sdk` license files also state MIT.
- Still required: inspect every package license and all workspace dependency lockfiles; check bundled fonts/icons/assets and any externally hosted cloud service boundary.

### Bagisto
- Root `LICENSE` and `composer.json` both state MIT.
- Still required: Composer lock dependency-license scan; frontend package and asset scan; inspect bundled themes, icons, fonts and all first-party package notices.

### Krayin CRM
- Root `LICENSE` and `composer.json` state MIT.
- Project documentation distinguishes the open-source core from hosted/cloud offerings and paid extensions. Do not assume paid extensions or external marketplace packages are included in the MIT grant.
- Still required: Composer/npm dependency scan; inspect bundled assets and any code copied from separately distributed extensions.

### AureusERP
- Root `LICENSE` and `composer.json` state MIT.
- Composer configuration uses a merge plugin to include `plugins/*/*/composer.json`; therefore the plugin tree is part of the effective dependency inventory and must be audited recursively.
- Still required: audit all merged plugin manifests, lockfiles, bundled assets and package notices; independently assess project maturity and operational suitability.

### FastAPI full-stack template
- Root `LICENSE` states MIT. The repository uses a uv workspace with a backend member and lockfiles.
- Still required: resolve and audit all Python and frontend dependencies from the lockfiles; inspect bundled images, fonts and other assets.

### DocsGPT
- Root `LICENSE` and `pyproject.toml` identify MIT.
- The Python manifest declares a substantial runtime dependency set, including model/runtime and document-processing integrations.
- Still required: audit the complete resolved Python dependency graph, optional extras, downloaded models, document-conversion components, frontend dependencies and bundled assets.

### AnythingLLM
- Root `LICENSE` and root `package.json` identify MIT.
- It is a multi-part application (server, frontend, collector and additional integrations); root metadata does not establish the licenses of each workspace dependency or bundled component.
- Still required: inspect every nested package manifest and lockfile, native/desktop/mobile components, icons/fonts, models and optional integrations.

### Coolify
- Root `LICENSE` and `composer.json` identify Apache-2.0.
- The repository contains deployment templates for third-party services (including an EMQX Enterprise template). A deployment template does not grant rights to redistribute the third-party service image or its branding.
- Still required: scan Composer/frontend dependencies, all deployment templates, bundled assets and any third-party container/image references; define an exclusion list for non-permissive services.

### InvenTree
- Root `LICENSE`, `docs/LICENSE` and `src/frontend/LICENSE` state MIT.
- Recursive tree inspection found a separate Tabler Icons license file; its terms and attribution requirements must be retained and checked against the intended redistribution.
- Still required: audit Python/frontend dependency lockfiles, plugin ecosystem boundaries, all icons/fonts/images and any third-party assets.

### Medplum
- Root `LICENSE.txt` states Apache-2.0. The repository also contains a `NOTICE` file identifying Medplum as a registered trademark of Orangebot, Inc.
- Apache code rights do not grant ownership or unrestricted rights to the Medplum trademark, logo or branding. Preserve the NOTICE and rebrand the derivative product appropriately.
- Still required: audit all package manifests/lockfiles, SDK and generated assets, fonts/icons, bundled resources and dependency licenses.

## Acquisition gate

Do not create any `tpl-*` repository from this list yet. Promote a candidate to APPROVED only after a reproducible dependency and asset audit is attached to the exact source commit above and all exclusions/attributions are documented. Once approved, submit one owner-authored `[acquire-repo]` issue for that candidate and independently verify the mirror.
