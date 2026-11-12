# Transient Argon / Carbon model tool

This is a disposable integration entry for `veerack/argon-webapp`.

It intentionally does **not** vendor the upstream application into Agent Workspace. The tracked files here are only the launcher, manifest, and lifecycle documentation. The upstream application is cloned into a local runtime directory when needed and can be removed completely afterward.

## Purpose

Use Gemini 4 Argon and Gemini 4 Carbon through the upstream local web application for short-lived agent consultation and delegated implementation work.

This is a model/agent tool, not a permanent Agent Workspace provider.

## Start

From this directory:

```bash
./run.sh /absolute/path/to/target/repository
```

The launcher:

1. clones the pinned upstream repository into a runtime directory if absent;
2. creates/reuses a Python virtual environment there;
3. installs the upstream requirements;
4. sets `STUDIO_WORKSPACE` to the requested target repository;
5. starts the upstream Flask application on port `4321`.

Authenticate Google Vertex AI separately with Application Default Credentials:

```bash
gcloud auth application-default login
```

Then configure the Google Cloud project/location in the Argon UI if they are not already supplied through the upstream settings.

## Cleanup

```bash
./cleanup.sh
```

Cleanup removes only the transient Argon runtime and virtual environment. It does not touch the target workspace.

## Security boundary

Argon/Carbon can read and modify the configured workspace and can execute terminal commands there. Only point it at a repository that the temporary agent is explicitly allowed to modify. Never place credentials or secrets in the tracked tool directory.

## Upstream

Repository: https://github.com/veerack/argon-webapp

The upstream application currently exposes Gemini 4 Argon and Carbon through Google Vertex AI and uses the official `google-genai` SDK. Its own README warns that usage can consume Google Cloud credits and quotas.

This wrapper deliberately keeps the upstream source disposable so the Agent Workspace architecture remains independent of this short-lived model availability.
