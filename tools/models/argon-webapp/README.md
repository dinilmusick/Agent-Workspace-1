# Transient Argon / Carbon model tool

This is a disposable integration entry for `veerack/argon-webapp`.

It intentionally does **not** vendor the upstream application into Agent Workspace. The tracked files here are only the launcher, manifest, environment template, and lifecycle documentation. The upstream application is cloned into a local runtime directory when needed and can be removed completely afterward.

## Purpose

Use Gemini 4 Argon and Gemini 4 Carbon through the upstream local web application for short-lived agent consultation and delegated implementation work.

This is a model/agent tool, not a permanent Agent Workspace provider.

## Configure

Copy the template:

```bash
cp .env.example .env
```

Set:

```dotenv
GOOGLE_CLOUD_PROJECT=your-temporary-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

Do **not** put Google credentials or service-account JSON into this directory. The Vertex path uses local Application Default Credentials (ADC).

Optional variables:

- `GEMINI_API_KEY`: only for the upstream app's API-key mode; leave empty for Vertex/ADC.
- `ARGON_WEBAPP_REF`: upstream Git ref, default `main`.
- `ARGON_WEBAPP_RUNTIME_DIR`: local disposable runtime location.

The real `.env` is ignored by Git. Only `.env.example` is tracked.

## Authenticate Google

For local Vertex use:

```bash
gcloud auth application-default login
```

This stores local ADC credentials; it does not put them in Agent Workspace.

## Start

From this directory:

```bash
./run.sh /absolute/path/to/target/repository
```

The launcher:

1. clones the pinned upstream repository into a runtime directory if absent;
2. creates/reuses a Python virtual environment there;
3. installs the upstream requirements;
4. loads the local `.env` configuration;
5. sets `STUDIO_WORKSPACE` to the requested target repository;
6. starts the upstream Flask application on port `4321`.

Open:

```text
http://localhost:4321
```

## Cleanup

```bash
./cleanup.sh
```

Cleanup removes only the transient Argon runtime and virtual environment. It does not touch the target workspace or Google Cloud project.

## Google project lifecycle

Create a dedicated Google Cloud project for this temporary experiment. Enable billing on that project and enable the Vertex AI API. Keep the project isolated from production resources.

When finished, first stop the Argon process and remove the local runtime, then delete the temporary Google Cloud project. Deleting the project stops future project-level usage, but any already-incurred billable usage is still subject to the billing account's normal billing process.

## Security boundary

Argon/Carbon can read and modify the configured workspace and can execute terminal commands there. Only point it at a repository that the temporary agent is explicitly allowed to modify. Never place credentials or secrets in the tracked tool directory.

## Upstream

Repository: https://github.com/veerack/argon-webapp

The upstream application currently exposes Gemini 4 Argon and Carbon through Google Vertex AI and uses the official `google-genai` SDK. Its own README warns that usage can consume Google Cloud credits and quotas.

This wrapper deliberately keeps the upstream source disposable so the Agent Workspace architecture remains independent of this short-lived model availability.
