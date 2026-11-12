# User-Authorized Private Template Acquisitions

Decision date: 2026-11-12
Authorization: The repository owner explicitly directed the workspace to begin adding the selected independent template repositories without further pre-acquisition testing.

This authorization permits **private internal research acquisition only** for the 29 full-source mirror entries and six reference-only entries in the canonical docs/template-portfolio-catalog.md. That catalog is the exact source/destination/branch/commit authorization record enforced by the acquisition workflow. This does not certify that any optional dependency, asset, font, model, extension, trademark, or full distribution configuration has been cleared for commercial redistribution. Preserve all upstream notices and license files. Do not publish these copies, distribute binaries containing uncleared components, or offer derivative SaaS containing restricted components until those specific obligations have been reviewed. Copyleft projects may be mirrored privately only under their existing license for internal study; they remain excluded from commercial reuse unless separately cleared. Reference-only candidates must contain no upstream code, assets, binaries, dependencies, or history.

The table below records the earlier initial acquisition set; it is historical provenance and is not the exhaustive current portfolio. The canonical catalog controls the current 35 additional entries and their exact pins.\n\n| Category | Source | Destination | Root license basis | Exact source commit |
|---|---|---|---|---|
| Documentation | meta/docusaurus | tpl-docs-docusaurus | MIT | c00f04e2376e057090d65d6bfb6a82d49ea3eca6 |
| Static site generator | gohugoio/hugo | tpl-static-hugo | Apache-2.0 | afb2d9ac7558afebe05bd2bcb399311f33d7fff1 |
| Visual website builder | GrapesJS/grapesjs | tpl-website-grapesjs | BSD-3-Clause | e023d69b9fa97fbbc693052c9818f0c477b105a5 |
| Wiki / knowledge base | BookStackApp/BookStack | tpl-knowledge-bookstack | MIT | 0b6b667e0d84ebb3406de6de9fadbf4230c29c0b |
| SaaS starter | nextjs/saas-starter | tpl-saas-nextjs | MIT | 6e33e58b1e553a41fe22e6b941a7229a002de361 |
| Admin framework | refinedev/refine | tpl-admin-refine | MIT | 2352eb5b6539e2f39ad9aef652279ad1dcf2c467 |
| Project management | kanboard/kanboard | tpl-project-kanboard | MIT | 60d2caf29edfa58e313b17cadaab76b6d4307742 |
| Forum | flarum/flarum | tpl-community-flarum | MIT | 0e4cfab174a02b1974ae212f88883b5ae871c72a |
| Workflow automation | node-red/node-red | tpl-automation-nodered | Apache-2.0 | fb9a09410b75ff4782cf5f7d4d6a337bdde5191b |
| Durable orchestration | temporalio/temporal | tpl-orchestration-temporal | MIT | 03ecd1d228d2b8d9d433da55785afc9aeeead918 |

Acquisition method: create a new private repository under dinilmusick, mirror source history and writable refs, do not create a GitHub fork, preserve upstream license and notice files, and verify destination refs/default branch. Never overwrite an existing destination. If the source head has moved beyond the pinned commit or the workflow's source-head check fails, stop and refresh the exact commit rather than silently mirroring a different revision.

This is a user-authorized internal acquisition record, not a legal opinion or a declaration that the complete software bill of materials is permissively licensed.
