# Template Portfolio — Initial Candidate Audit

Snapshot date: 2026-11-12 (UTC)
Policy: [Commercial Repository Acquisition Policy](commercial-acquisition-policy.md)

This register captures the first ten priority candidates. It is **not a legal clearance or acquisition approval**. Every candidate remains CONDITIONAL until dependency, bundled-asset, font, icon, model, extension, and trademark checks are complete for the exact source revision. No candidate in this register is currently authorized for cloning.

## Candidate register

| Category | Source | Destination | Default branch | Root SPDX | Root license file | Exact source commit | Status |
|---|---|---|---|---|---|---|---|
| CMS | [payloadcms/payload](https://github.com/payloadcms/payload) | `tpl-cms-payload` | `main` | MIT | `LICENSE.md` | `fd82d9dd0321dac0f15efe1474be4e923ecef750` | CONDITIONAL |
| E-commerce | [bagisto/bagisto](https://github.com/bagisto/bagisto) | `tpl-commerce-bagisto` | `2.5` | MIT | `LICENSE` | `add2920a8ecdb8e892b9abeec31520a62c2090e8` | REJECTED (current runtime dependency set) |
| CRM | [krayin/laravel-crm](https://github.com/krayin/laravel-crm) | `tpl-crm-krayin` | `2.2` | MIT | `LICENSE` | `ed6deebfcb8c616eaf352c893a10a6d8e666fc6e` | REJECTED (current runtime dependency set) |
| ERP | [aureuserp/aureuserp](https://github.com/aureuserp/aureuserp) | `tpl-erp-aureuserp` | `master` | MIT | `LICENSE` | `c31a0db21e00fa436c4949eb4f60ceef81e116ec` | REJECTED (current runtime dependency set) |
| Python API starter | [fastapi/full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template) | `tpl-backend-fastapi` | `master` | MIT | `LICENSE` | `aabb90126964a164e02aff39e7c385bb0598236d` | REJECTED (runtime dependency licenses) |
| RAG | [arc53/DocsGPT](https://github.com/arc53/DocsGPT) | `tpl-ai-docsgpt` | `main` | MIT | `LICENSE` | `d1506d977d0c2036a07e7b464fa05479fab8d973` | REJECTED (runtime LGPL dependency) |
| AI workspace | [Mintplex-Labs/anything-llm](https://github.com/Mintplex-Labs/anything-llm) | `tpl-ai-anythingllm` | `master` | MIT | `LICENSE` | `e8434c07c3d385411aec28e8f9758dfd073565ec` | REJECTED (runtime LGPL libvips dependency) |
| Self-hosted PaaS | [coollabsio/coolify](https://github.com/coollabsio/coolify) | `tpl-deployment-coolify` | `main` | Apache-2.0 | `LICENSE` | `d9ab3d1e8bea98215ed19a27f2f4ac1abd2fa40f` | REJECTED (current runtime dependency set) |
| Inventory | [inventree/InvenTree](https://github.com/inventree/InvenTree) | `tpl-inventory-inventree` | `master` | MIT | `LICENSE` | `16309370ba0e4b4a088516ae06c0a681e5315348` | REJECTED (runtime LGPL dependencies) |
| Healthcare platform | [medplum/medplum](https://github.com/medplum/medplum) | `tpl-health-medplum` | `main` | Apache-2.0 | `LICENSE.txt` | `cfd9d414ce458eb802f36d41318c7dc031b511a3` | CONDITIONAL |

## Replacement candidates under review

The four rejected candidates above are not replaced automatically. These alternatives have a permissive root license and better category alignment, but their full dependency and asset audits are still pending.

| Category | Candidate | Proposed destination | Default branch | Root SPDX | Exact source commit | Status |
|---|---|---|---|---|---|---|
| CRM | [Django-CRM/Django-CRM (BottleCRM)](https://github.com/Django-CRM/Django-CRM) | `tpl-crm-bottlecrm` | `master` | MIT | `f63fe8cf22bd818cea45427b48ef59da24206ff1` | CONDITIONAL |
| E-commerce | [saleor/saleor](https://github.com/saleor/saleor) | `tpl-commerce-saleor` | `main` | BSD-3-Clause | `ea4a69fa6faa22de77a30eaee0447dd7dacaadb3` | CONDITIONAL |
| PaaS | [dokku/dokku](https://github.com/dokku/dokku) | `tpl-deployment-dokku` | `master` | MIT | `bf03afb9810caea112f2ea2e203b21da4f84c382` | CONDITIONAL |
| ERP | [apache/ofbiz-framework](https://github.com/apache/ofbiz-framework) | `tpl-erp-ofbiz` | `trunk` | Apache-2.0 | `e641b3a61866d591e192b9bc585d4349e4821c95` | CONDITIONAL |

### Replacement notes

- **BottleCRM — REJECTED as-is:** root `LICENSE` and backend `pyproject.toml` state MIT, but the backend directly declares runtime `psycopg[binary,pool]>=3.3.6` for PostgreSQL pooling. PyPI identifies Psycopg 3.3.8 as `LGPL-3.0-only`; this violates the user's no-LGPL rule. <https://pypi.org/project/psycopg/> The exact revision also has a frontend `pnpm-lock.yaml`; that graph and all assets remain unreviewed, but the direct runtime blocker is sufficient to reject this revision. Do not acquire unless the PostgreSQL driver is replaced with an allowlisted alternative, the uv lock is regenerated, and the frontend graph is fully audited.
- **Saleor — REJECTED as-is:** root `LICENSE` is BSD-3-Clause. Exact-commit dependency review covered 228 npm lock entries (their lockfile license fields) and 231 Python packages from `uv.lock` with PyPI version metadata. Nine packages were flagged as GPL/LGPL/MPL; crucially, `pyproject.toml` directly declares runtime `pybars3` (LGPL), `text-unidecode` (GPL/Artistic), `psycopg[binary]` (LGPL-3.0-only) and `orjson` (MPL-2.0 AND Apache-2.0 OR MIT). `certifi` and `pathspec` also report MPL-2.0. These runtime dependencies violate the user's no-copyleft/permissive-only policy. Do not acquire this revision unless incompatible dependencies are replaced and the full graph is re-locked and re-audited.
- **Dokku:** root `LICENSE` is MIT. It contains many independent Go modules across plugins; the tree also includes an Apache-2.0 nested `helmdiff` license and an MIT Scala test fixture license. Every production Go module and bundled helper must be scanned, and all notices retained.
- **Apache OFBiz:** root `LICENSE` is Apache-2.0 and root `NOTICE` identifies Apache Software Foundation copyright. The project bundles a large Java/Gradle ecosystem; inspect all bundled JARs and Gradle-resolved dependencies before any approval.
- **Medusa:** not selected as the commerce replacement. Its README identifies an open-core model and an `ENTERPRISE-LICENSE.md` governing RBAC-based Enterprise Edition materials under a separate commercial agreement. The entire repository therefore does not meet the requested unrestricted-permissive acquisition rule.
- **Frappe CRM:** rejected as a CRM replacement because the repository is AGPL-3.0.

## Evidence and outstanding checks

### Payload CMS
- GitHub repository metadata reports MIT; the root `LICENSE.md` grants commercial use, modification, distribution and sale subject to retaining notices.
- Recursive tree inspection found many package-level license files. Sampled `packages/payload-cloud`, `packages/payload`, `packages/plugin-ecommerce`, `packages/plugin-stripe` and `packages/sdk` license files also state MIT.
- Still required: inspect every package license and all workspace dependency lockfiles; check bundled fonts/icons/assets and any externally hosted cloud service boundary.

### Bagisto — REJECTED as-is
- Root `LICENSE` and `composer.json` both state MIT.
- Parsed `composer.lock` at the exact source commit recorded in the table: 235 locked packages total, including 181 runtime packages. Runtime dependencies include OSL-3.0 (`apimatic/jsonmapper`), LGPL packages (`dompdf/dompdf`, `php-font-lib`, `php-svg-lib`, `ezyang/htmlpurifier`, `ar-php`) and GPL packages (`enshrined/svg-sanitize`, `mpdf`). Nette packages also list BSD-3-Clause as their first license option and were not counted as incompatible.
- These runtime copyleft/restricted dependencies violate the user's permissive-only policy. Do not acquire this revision unless those dependencies are removed/replaced and the resulting application is re-locked and re-audited.
- Frontend package and asset audit remains outstanding; it cannot reverse the current rejection.

### Krayin CRM — REJECTED as-is
- Root `LICENSE` and `composer.json` state MIT.
- Parsed `composer.lock` at the exact source commit recorded in the table: 191 locked packages total, including 131 runtime packages. Runtime dependencies include LGPL packages (`dompdf/dompdf`, `php-font-lib`, `php-svg-lib`, `ezyang/htmlpurifier`, `ar-php`, `smalot/pdfparser`) and GPL packages (`enshrined/svg-sanitize`, `mpdf`). `prettus/laravel-validation` has no license metadata in the lock. Nette packages list BSD-3-Clause as their first license option and were not counted as incompatible.
- These runtime copyleft dependencies and the missing license metadata violate the user's strict allowlist. Do not acquire this revision unless dependencies are removed/replaced and the complete graph is re-audited.
- Project documentation also distinguishes the open-source core from hosted/cloud offerings and paid extensions; those external add-ons are not assumed to be MIT.

### AureusERP — REJECTED as-is
- Root `LICENSE` and `composer.json` state MIT. Composer configuration merges `plugins/*/*/composer.json` into the effective dependency graph.
- Parsed `composer.lock` at the exact source commit recorded in the table: 221 locked packages total, including 174 runtime packages. Runtime dependencies include LGPL packages (`dompdf/dompdf`, `php-font-lib`, `php-svg-lib`, `ezyang/htmlpurifier`, `ar-php`, `milon/barcode`). Nette packages list BSD-3-Clause as their first license option and were not counted as incompatible.
- The runtime LGPL dependencies violate the user's permissive-only policy. Do not acquire this revision unless these dependencies are removed/replaced and the merged plugin graph is re-audited.
- Operational maturity and bundled asset review also remain outstanding.

### FastAPI full-stack template — REJECTED as-is
- Root `LICENSE` states MIT. The exact source commit contains `uv.lock` and `bun.lock`; the uv lock declares Python `>=3.14` and contains a 672-package combined lock inventory across Python and frontend dependency sets.
- Queried the PyPI JSON and npm registry metadata for every resolved package/version in both locks (669 successful metadata responses; 3 fetch errors). Results: 537 MIT, 37 Apache-2.0, 15 BSD-3-Clause, 9 BSD-2-Clause, 15 ISC, 2 0BSD, plus 54 unresolved/non-allowlisted entries and 3 fetch errors.
- Confirmed runtime packages `psycopg` and `psycopg-binary` are `LGPL-3.0-only`; the graph also contains `MPL-2.0` packages (including `certifi`, `pathspec`, `lightningcss`), `CC-BY-4.0` (`caniuse-lite`), and `BlueOak-1.0.0` (`glob`). `Unlicense`, `Python-2.0`, BSD-like and BSD-generic metadata also require separate review under the user's strict allowlist.
- The runtime LGPL and other non-allowlisted components disqualify this exact revision. Do not acquire unless those dependencies are removed/replaced and both lockfiles are regenerated and fully re-audited.
- ScanCode source-tree scanning was attempted but the runner's release configuration failed; no source-level ScanCode results are claimed. Asset review remains outstanding.

### DocsGPT — REJECTED as-is
- Root `LICENSE` and `pyproject.toml` identify MIT. The exact source revision has multiple lock/requirements files for core, document parsing, vector stores, decision models, tests and docs.
- The core `pyproject.toml` directly declares `psycopg[binary,pool]>=3.1,<4` as a runtime dependency; the pinned `docsgpt/requirements.txt` contains `psycopg==3.3.8` and `psycopg-binary==3.3.8`. PyPI identifies Psycopg 3.3.8 as `LGPL-3.0-only`, which violates the user's explicit no-LGPL rule. <https://pypi.org/project/psycopg/>
- This direct runtime blocker is sufficient to reject the current revision. The full lock includes optional Docling/Milvus/decision-model extras and multiple npm lockfiles; their dependency, model and asset reviews remain outstanding. Do not acquire unless the PostgreSQL driver is replaced with an allowlisted alternative and every supported configuration is re-locked and re-audited.

### AnythingLLM — REJECTED as-is
- Root `LICENSE` and root/server/collector/frontend package manifests identify MIT.
- The collector declares runtime dependency `sharp@^0.33.5` and uses it in `collector/utils/OCRLoader/index.js` to convert PDF pages to image buffers.
- The exact collector `yarn.lock` pins `sharp@0.33.5` and optional platform packages `@img/sharp-libvips-*@1.0.4/1.0.5`. The Linux x64 libvips package is LGPL-3.0-or-later and contains LGPLv3 components including libvips, glib, libexif, libheif, librsvg and pango. This is a runtime image-processing path, not merely an unrelated development dependency. <https://www.npmjs.com/package/@img/sharp-libvips-linux-x64>
- The LGPL runtime dependency violates the user's explicit no-LGPL rule. Do not acquire this revision unless the image-processing path is replaced with a fully allowlisted alternative and the complete server/collector/frontend/desktop dependency and asset graphs are re-audited.

### Coolify — REJECTED as-is
- Root `LICENSE` and `composer.json` identify Apache-2.0.
- Parsed `composer.lock` at the exact source commit recorded in the table: 240 locked packages total, including 167 runtime packages. Runtime dependencies include LGPL (`ezyang/htmlpurifier`) and GPL-3.0-or-later (`poliander/cron`). The development-only `serversideup/spin` package is also GPL-3.0-or-later. Nette packages list BSD-3-Clause as their first license option and were not counted as incompatible.
- The runtime GPL/LGPL dependencies violate the user's permissive-only policy. Do not acquire this revision unless they are removed/replaced and the complete graph is re-audited.
- The repository also contains third-party deployment templates (including an EMQX Enterprise template); a template does not grant rights to redistribute the third-party image or its branding.

### InvenTree — REJECTED as-is
- Root `LICENSE`, `docs/LICENSE` and `src/frontend/LICENSE` state MIT. The nested Tabler Icons license is MIT and must be retained.
- At the exact commit in the table, the pinned backend `requirements.txt` contains 154 Python packages. PyPI metadata review identified runtime dependencies `jwcrypto` (`LGPL-3.0-or-later`) and `paramiko` (`LGPL-2.1`), plus `docutils` metadata offering GPL and `dulwich` metadata offering Apache-2.0 OR GPL-2.0-or-later. The two LGPL runtime dependencies alone violate the user's exclusion rule. The backend scan also found 51 ambiguous/non-allowlisted metadata entries and 2 metadata fetch failures.
- The frontend manifest includes `@fortawesome/free-solid-svg-icons` and `@fortawesome/free-regular-svg-icons`. Font Awesome Free separates licenses: SVG/JS icons are CC BY 4.0, font files are SIL OFL 1.1, and non-font/non-icon code is MIT. CC BY and OFL permit commercial distribution subject to attribution/notice and font-specific terms, but these are additional obligations; preserve all embedded attribution comments and notices. Do not treat the entire Font Awesome package as MIT. Official licensing evidence: Font Awesome's project README and license text describe these distinct grants and attribution requirements.
- A second full frontend registry audit is incomplete; a parallel broad scan is still running. This does not change the rejection because the backend LGPL runtime dependencies are already sufficient. Do not acquire this revision unless those dependencies are removed/replaced, the backend lock is regenerated, and the full Python/frontend dependency and asset graphs are re-audited.

### Medplum — REJECTED as-is
- Root `LICENSE.txt` is Apache-2.0. The repository `NOTICE` identifies Medplum as a registered trademark of Orangebot, Inc.; Apache copyright/patent grants do not grant trademark rights. Preserve NOTICE and rebrand any distributed derivative rather than implying Medplum endorsement.
- Parsed the exact source commit's root `package-lock.json`: 1,997 npm package entries, 704 runtime entries. Runtime package license metadata contains no GPL/LGPL/MPL/EPL-only package. Two runtime packages declare `MIT OR GPL-3.0-or-later` (`case`, `jszip`), so the MIT option must be selected and documented. Other runtime metadata includes BlueOak-1.0.0, PSF-2.0, CC0, Unlicense and WTFPL/ISC expressions; these are not copyleft-only but fall outside the preferred SPDX allowlist and require notice/attribution review.
- The 57 runtime entries with missing lockfile license metadata include 28 first-party `@medplum/*` workspace packages plus local examples. External entries checked against upstream/source records: `ssh2`, `cpu-features`, `buildcheck`, `memorystream` have MIT license files in their source repositories; `thirty-two` is MIT; `png-js` is reported MIT. Npm's registry metadata omits license fields for some of these packages, so retain their source LICENSE files and add explicit notices.
- The exact source tree contains 524 image/font/vector/PDF assets. In particular, `packages/bot-layer/fonts/Avenir/Avenir.ttf` is bundled without a corresponding font license or attribution file in the repository tree. The root Apache-2.0 grant does not establish redistribution rights for this third-party font. This unlicensed asset is sufficient to reject the unmodified repository under the portfolio policy. Replace it with a properly licensed font and document the source/license of all screenshots, photos, logos and generated/third-party data before reconsideration.
- Dev-only package entries include MPL-2.0, EPL/GPL dual-license, CC-BY-4.0 and other additional terms; they must be assessed if the development toolchain or those packages are distributed with a deliverable.
- Do not acquire this revision as-is. Reconsider only after removing/replacing the Avenir font, auditing the remaining asset corpus and optional vendor integrations (including DoseSpot and Health Gorilla packages), retaining all dependency notices, and revalidating trademark exclusions.

## Acquisition gate

Do not create any `tpl-*` repository from this list yet. Promote a candidate to APPROVED only after a reproducible dependency and asset audit is attached to the exact source commit above and all exclusions/attributions are documented. Once approved, submit one owner-authored `[acquire-repo]` issue for that candidate and independently verify the mirror.
