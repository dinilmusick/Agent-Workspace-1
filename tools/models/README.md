# Model and agent tools

This directory contains small, explicit adapters and launchers for external models or agents that Agent Workspace may consult or delegate work to.

## Contract

A model/agent tool should:

- be independently runnable and disposable;
- keep credentials outside the repository;
- receive an explicit target workspace rather than ambient repository access;
- document its upstream source and lifecycle;
- expose a stable local entry point even when the upstream implementation changes;
- never become a mandatory dependency of the Agent Workspace substrate unless explicitly promoted later.

## Current tools

- [Argon / Carbon](argon-webapp/README.md) — transient wrapper around `veerack/argon-webapp` for Gemini 4 Argon and Carbon through Google Vertex AI.

Future providers such as Google-native models, Cerebras, Groq, and OpenRouter can follow this same pattern without changing the core Agent Workspace execution substrate.
