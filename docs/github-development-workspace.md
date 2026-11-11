# GitHub Development Workspace

Agent Workspace can execute bounded development jobs against authorized GitHub repositories without requiring a workflow-dispatch API client.

## Trigger through an issue

Create an issue in `dinilmusick/Agent-Workspace-1`:

- Title must begin with `[github-dev]`.
- The issue author must be a repository owner, member, or collaborator.
- The body must be a JSON object following this contract:

```json
{
  "repository": "dinilmusick/Aiko",
  "ref": "main",
  "commands": [
    "npm ci",
    "npm run typecheck",
    "npm test",
    "npm run build"
  ],
  "push": true,
  "branch": "agent/aiko-verification",
  "create_pr": true,
  "commit_message": "chore: verify Aiko implementation",
  "pr_title": "chore: verify Aiko implementation",
  "pr_body": "Summary and verification evidence."
}
```

The minimum request is `repository`, `ref`, and non-empty `commands`. Commands may be a string or an array of strings. A maximum of 100 command lines and 20,000 characters is enforced.

Set `push` to false (or omit it) to run checks without writing to the target repository. To push changes, set `push: true` and provide a new `branch`; the runner creates a commit and pushes that branch. Set `create_pr: true` to open a pull request against `ref` after the push. PR creation requires push.

## Security boundaries

- Only issue requests from repository owners, members, or collaborators are accepted.
- The target repository is checked out with `CODING_REPO_TOKEN`, with credential persistence disabled.
- Target commands do not receive repository, deployment, or workflow secrets.
- The write token is only exposed to the isolated push/PR steps after command execution.
- The workflow's own `GITHUB_TOKEN` has read-only contents/issue permissions.
- Run arbitrary commands only against trusted repositories. The authorized issue route is a code-execution capability, not a public sandbox.
- Each run uploads its command log as a seven-day artifact.

## Workflow-dispatch route

The same workflow retains its `workflow_dispatch` interface for callers that can dispatch Actions directly. Both routes use the same request validator.

## Local request validation tests

Run:

```bash
python3 -m unittest runner/test_resolve_development_request.py
```
