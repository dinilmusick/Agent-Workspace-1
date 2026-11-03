# GitHub repository tools

These scripts provide safe repository-management helpers for Agent Workspace.

## Authentication

Set one environment variable in the execution environment:

```text
GITHUB_TOKEN=<token>
```

`GH_TOKEN` is accepted as a compatibility fallback. Tokens are never accepted as command-line arguments and are never written to files.

## Create a repository

```bash
python3 tools/github/create_repository.py --name MyRepo --visibility private --description "Example"
```

Supported options include `--visibility private|public`, `--description`, `--private`, `--public`, `--initialize`, `--gitignore-template`, `--license-template`, and `--homepage`.

The tool calls GitHub's authenticated `POST /user/repos` API and returns the canonical repository URL and default branch. It does not clone, push, publish packages, or alter existing repositories.

## Validate without mutation

```bash
python3 tools/github/create_repository.py --name MyRepo --dry-run
```

Dry-run performs argument validation and reports the API operation that would be requested without contacting GitHub.

## Safety model

- No token on argv.
- No token in output.
- HTTPS-only GitHub API.
- Explicit repository name and visibility.
- Non-2xx responses are fatal.
- Existing repository conflicts are reported without mutation.
- No shell commands or third-party Python packages are required.
