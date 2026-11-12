# Commercial Repository Acquisition Policy

This policy governs every repository copied into the dinilmusick template portfolio.

## Eligibility gate

A candidate is eligible for commercial reuse only when all of the following are evidenced for the exact source revision and selected product configuration:

1. The root project license is explicitly identified and permits the intended commercial use, modification and redistribution.
2. The license is compatible with the intended client deliverable. Preferred identifiers for closed-source deliverables: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, Zlib and PostgreSQL.
3. No source directory, edition, plugin, extension, bundled asset, model, font, theme or other required component has a conflicting or commercial-use restriction.
4. Direct and transitive dependencies used by the selected product configuration have compatible licenses, or are explicitly excluded from the acquired product.
5. Required copyright, attribution, patent, notice and source-disclosure obligations can be fulfilled.
6. The source is not archived or disabled and passes operational suitability checks.

A GitHub SPDX badge or root LICENSE file alone is not sufficient. Missing, ambiguous, conflicting or unverified licensing means HOLD, not commercial approval.

## Statuses

- COMMERCIAL-APPROVED: all license and operational evidence is recorded for the exact configuration.
- CONDITIONAL: a specific obligation or component remains unresolved.
- REJECTED: incompatible or restricted license for the intended commercial distribution model.
- UNVERIFIED: evidence is insufficient.
- PRIVATE-STUDY-MIRROR: privately copied under the upstream open-source license for internal research only; no commercial clearance is implied.
- REFERENCE-ONLY: provenance record only; no upstream code or assets copied.

Only COMMERCIAL-APPROVED candidates may be incorporated into proprietary client deliverables. The workflow's SPDX allowlist is a second guardrail, not legal clearance and not a dependency audit. Every request must include the exact 40-character source commit currently at the source default branch head and a link to the workspace approval evidence. The workflow rejects requests without both fields or when the source branch has moved.

## Independent copy semantics

For an approved private research mirror or commercial candidate:

1. Create a new private repository under dinilmusick; never create a GitHub fork.
2. Clone the source using `git clone --mirror`.
3. Mirror all advertised, writable source refs and history to the destination using `git push --mirror`. Exclude GitHub-managed refs such as `refs/pull/*` and `refs/merge-queue/*`, which are not writable destination refs.
4. Pin the acquisition to the approved source commit, require that it is still the source default-branch head, set the destination default branch to that source branch, then independently verify every mirrored ref and that the destination default-branch head equals the approved commit.
5. Preserve the original LICENSE, copyright and third-party notices.
6. Do not add an upstream remote. Development clones should use only the new dinilmusick repository as origin.
7. Record source URL, exact source commit, SPDX identifier, license evidence, dependency audit evidence and acquisition timestamp.

The destination remains private. Private visibility does not waive license obligations or create permission for commercial use.

## Private research acquisition (separate from commercial clearance)

The commercial-use gate above applies to incorporating, distributing, deploying or shipping copied code in a client deliverable. It does not prohibit a separate, owner-authorized **private research mirror** of a properly identified open-source project.

A private research mirror may be created for internal inspection, learning, comparative testing and architectural reference when the source has a recognized open-source license and the original license terms, copyright notices, attribution, NOTICE files and history are retained. Copyleft projects may be mirrored privately for research, but that does not make them eligible for closed-source or proprietary client work. Any later distribution, modification shipped to clients, or network service use must be reviewed against the exact license and configuration first.

If the source license is missing, ambiguous, source-available/fair-code, or contains additional restrictions that have not been resolved, acquire a **reference-only record**: copy no upstream source files, assets, binaries, Git history or dependencies. Record the upstream URL and exact commit only.

Every private research mirror remains private. Do not remove upstream notices, relicense the source, publish the mirror, or imply that an internal acquisition grants commercial rights. A complete per-product legal, dependency and asset review remains mandatory before any commercial reuse.

## Security

The acquisition workflow accepts requests only from the account owner. It reads the scoped `CODING_REPO_TOKEN` secret only inside GitHub Actions. Never print, echo, upload or write the token into repository files or artifacts. Do not execute source build scripts during the mirror operation.


## Acquisition workflow implementation safeguards

The owner-triggered acquisition controller validates the raw JSON request against the exact canonical catalog URL and verifies the source, destination and full commit SHA on the same catalog row. It re-queries the live source default-branch HEAD and requires exact SHA equality; ancestry alone is insufficient. Every issue-derived field is validated and emitted through unique multiline GitHub Actions output delimiters.

Destinations must be new private non-fork repositories. An existing destination is resumable only when its repository description contains a recognized ULTRST source, commit, category and acquisition-mode provenance marker. If the default branch advanced after a previously authorized acquisition attempt, the catalog must first be refreshed and the new HEAD reviewed. A provenance pin migration is permitted only for a private mirror with the same source/category/mode, unchanged default-branch name, a destination default-branch ref equal to the old marker's commit, and GitHub compare evidence that the old pin is a strict ancestor of the new reviewed pin. The destination description is updated to the new pin only after the live refs/history have been reconciled and verified. Exact refs are retained; fast-forward branches are advanced normally. When an upstream force-push, tag replacement or ref deletion means an old destination tip is no longer reachable from the live source ref, the old object is first preserved under refs/ultrst-archive/<ref-hash>/<object-sha>, then the live upstream refs are reconciled. The read-only verifier requires every live upstream writable ref to match exactly and validates every archive ref/object; malformed or unrelated refs are rejected. This preserves previous history without treating the old ref as the current upstream ref or discarding its objects. The workflow never overwrites or repurposes an unrelated repository. Mirror verification checks writable refs, reachable object IDs, Git connectivity, default branch, exact pinned SHA, privacy and non-fork status. Reference-only verification requires exactly one README.md file on main and no copied upstream content or history. Temporary Git remotes are removed, and the workflow does not execute upstream code or expose the coding token to logs/artifacts.
