---
name: "Diagram Engineering"
slug: diagram-engineering
version: 1.0.0
status: active
---

# Diagram Engineering

Domain-independent visual reasoning and diagram construction skill.

## Purpose
Turn a Vision, architecture, workflow, state model, dependency graph or explanation into a precise, readable diagram. Use for planning and communication across coding, research, learning, design, operations, business and general work.

## Procedure
1. Identify the diagram's purpose, audience, target, node types, relationships and required decisions.
2. Choose the smallest representation that preserves the important structure.
3. Establish hierarchy, grouping, direction, labels, spacing and connector semantics before drawing.
4. Render through the canonical tldraw projection when a Vision or persistent planning graph is involved.
5. Inspect both structured geometry and a visual representation.
6. Run a visual lint pass: overlap, crossings, ambiguous direction, unreadable labels, inconsistent spacing, orphan nodes and missing relationships.
7. Revise and re-check until the diagram communicates the intended structure.

## Design rules
Prefer deletion over decoration. Use consistent node geometry, explicit connector direction, meaningful proximity, whitespace, alignment and progressive disclosure. Never use color as the only semantic channel. Do not create a second editable source of truth outside Supabase.

## Agent references
Use the official tldraw Agent Starter Kit/AI integration patterns for structured canvas actions, visual context and post-write inspection. Use AgentsORG design-engineering's diagram-design concepts as a companion reference. Reuse principles, not copied implementation.

## Routing
Primary for diagram generation, visual decomposition and diagram critique. Pair with Prompt Map for complex graph extraction and tldraw for persistent canvas projection.
