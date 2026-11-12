# GitHub Development Tools

These tools turn Agent-Workspace-1 into a GitHub-native development substrate.

## Capabilities

- `create-repository.sh`: create a public/private repository through the GitHub REST API.
- `scaffold-skipo-app.sh`: clone canonical Skipo, scaffold a new application directly into a target repository, validate it, commit and push.
- `github-dev-workspace.yml`: use GitHub-hosted compute to clone, edit, build, lint, test and optionally push any authorized repository.
- `create-skipo-app.yml`: create a repository and immediately scaffold a Skipo application into it.

## Token boundary

`CODING_REPO_TOKEN` is the coding credential. It must never be printed or placed in generated files.

Repository creation requires GitHub **Repository creation: write** permission. Private target repositories additionally require appropriate repository access and Contents: write for direct commits.

## Development loop

```text
intent
  -> create/select repository
  -> optional Skipo scaffold
  -> GitHub-hosted development workspace
  -> edit
  -> install
  -> lint/typecheck/test/build
  -> evidence artifact
  -> commit/push
  -> GitHub Actions verification
```

Agents do not require Supabase for this loop. Supabase adds persistent goal/task/evidence coordination; GitHub is sufficient for repository state, source, workflows, CI evidence and execution.

## Security

Only run coding commands against repositories and workflow definitions you trust. A workflow with `CODING_REPO_TOKEN` can modify the target repository. Keep deployment credentials out of this workflow.


## Independent commercial acquisition

Use `.github/workflows/independent-commercial-acquisition.yml` only for private research acquisitions explicitly listed in `docs/template-portfolio-catalog.md`. Create an owner-authored issue titled `[acquire-repo] <target>` with a raw JSON body containing exactly `source_repository`, `source_commit` (full lowercase 40-character SHA), `target_repository`, `category`, `acquisition_mode` (`mirror` or `reference-only`), and `approval_record` (the canonical catalog URL). The validator re-queries the source default branch and rejects unless its HEAD exactly equals the catalog pin; it also verifies that source, target and commit occur together in the catalog. Issue-derived values are validated and written to Actions outputs with unique multiline delimiters.

The acquisition script creates a new private non-fork destination and records an exact source/commit/mode provenance marker in its repository description. Existing destinations are never overwritten or repurposed: they can be resumed only when the provenance marker matches. Exact refs are retained and fast-forward branches are advanced normally. If an upstream force-push, tag replacement or ref deletion makes an old destination tip diverge, that previous tip is preserved under the explicit refs/ultrst-archive namespace before live source refs are reconciled. The read-only verifier requires every live upstream ref to match exactly and validates every preservation ref/object; unrelated or malformed refs are rejected. Mirrors copy all writable advertised refs/history, exclude GitHub-managed pull/merge-queue refs, remove temporary remotes, and verify refs, reachable objects, fsck, default branch, pinned commit, privacy and non-fork status. The workflow rechecks live license metadata immediately before acquisition.

After acquisition, a separate read-only verification script runs in its own process. It independently re-queries source/destination metadata, checks the exact live source pin and license metadata, compares all writable refs and reachable object IDs, and confirms the destination remains private and non-fork. Reference-only records must contain exactly one README.md on main and exactly one commit; no upstream source material or history is copied. The workflow never runs upstream project code and never prints or artifacts the coding token.

Regression tests: `python3 -m unittest tools/github/acquisition/test_validate_request.py`. Acquisition is private research only, not commercial clearance; complete dependency, asset, model, font, extension, trademark and distribution review remains mandatory before commercial use.
