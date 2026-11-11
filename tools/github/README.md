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

Use `.github/workflows/independent-commercial-acquisition.yml` only after the candidate is APPROVED under `docs/commercial-acquisition-policy.md`. The workflow accepts an owner-authored `[acquire-repo]` issue containing JSON fields `source_repository`, `source_commit`, `target_repository`, `category`, and `approval_record`. It requires the approved commit to remain the current source default-branch head, checks the source repository's SPDX metadata against a permissive allowlist, creates a new private repository, mirrors Git refs/history, and verifies all mirrored refs, the pinned default-branch commit, private visibility and non-fork status. The workflow does not itself perform a full transitive dependency, asset, model, font, extension or trademark audit; that evidence must exist before the request is submitted.
