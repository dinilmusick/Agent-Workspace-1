# Commercial Repository Acquisition Policy

This policy governs every repository copied into the dinilmusick template portfolio.

## Eligibility gate

A candidate is eligible only when all of the following are evidenced for the exact source revision being acquired:

1. The root project license is explicitly identified and permits commercial use, modification and redistribution.
2. The license is permissive and compatible with closed-source commercial client deliverables. Preferred identifiers: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, Zlib and PostgreSQL.
3. No source directory, edition, plugin, extension, bundled asset, model, font, theme or other required component has a conflicting or commercial-use restriction.
4. Direct and transitive dependencies used by the selected product configuration have compatible licenses, or are explicitly excluded from the acquired product.
5. Required copyright, attribution, patent, notice and source-disclosure obligations can be fulfilled.
6. The source is not archived or disabled and passes operational suitability checks.

A GitHub SPDX badge or root LICENSE file alone is not sufficient. Missing, ambiguous, conflicting or unverified licensing means HOLD, not approval.

## Statuses

- APPROVED: all license and operational evidence is recorded.
- CONDITIONAL: a specific obligation or component remains unresolved.
- REJECTED: incompatible or restricted license.
- UNVERIFIED: evidence is insufficient.

Only APPROVED candidates may be submitted to the independent acquisition workflow. The workflow's SPDX allowlist is a second guardrail, not legal clearance and not a dependency audit. Every request must include the exact 40-character source commit currently at the source default branch head and a link to the workspace approval evidence. The workflow rejects requests without both fields or when the source branch has moved.

## Independent copy semantics

For an approved candidate:

1. Create a new private repository under dinilmusick; never create a GitHub fork.
2. Clone the source using `git clone --mirror`.
3. Mirror all advertised, writable source refs and history to the destination using `git push --mirror`. Exclude GitHub-managed refs such as `refs/pull/*` and `refs/merge-queue/*`, which are not writable destination refs.
4. Pin the acquisition to the approved source commit, require that it is still the source default branch head, set the destination default branch to that source branch, then independently verify every mirrored ref and that the destination default-branch head equals the approved commit.
5. Preserve the original LICENSE, copyright and third-party notices.
6. Do not add an upstream remote. Development clones should use only the new dinilmusick repository as origin.
7. Record source URL, exact source commit, SPDX identifier, license evidence, dependency audit evidence and acquisition timestamp.

The destination remains private until the product-specific commercial redistribution audit is complete. Private visibility does not waive license obligations.

## Security

The acquisition workflow accepts requests only from the account owner. It reads the scoped `CODING_REPO_TOKEN` secret only inside GitHub Actions. Never print, echo, upload or write the token into repository files or artifacts. Do not execute source build scripts during the mirror operation.
