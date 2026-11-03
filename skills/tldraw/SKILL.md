---
name: "tldraw"
slug: tldraw
version: 1.1.0
source: Supabase Skills Database
sourceId: 1
status: active
---

# tldraw

Use tldraw as the mandatory visual projection layer for Vision decomposition, not as the source of truth. Every persisted Vision must have a synchronized tldraw representation unless the user explicitly declines visual projection for that Vision.

## Vision board protocol

A Vision has exactly one root target and a persisted target-decomposition graph. When a Vision is created:

1. Ask the user which tldraw workspace to use.
2. Create a new board in that workspace.
3. Create/identify the **Vision Overview** page.
4. Create one page for every component target.
5. On the overview page, render component targets as rectangles and place their goals beneath them.
6. Connect parent/component targets with arrows; keep arrows clear of shapes.
7. On each component page, render the target, its goals, and current task/verification state.
8. Persist board/workspace/page identifiers in Supabase.
9. Treat Supabase goal/task state as canonical; tldraw is a synchronized projection.

## Diagram-quality protocol
Use the tldraw Agent patterns: inspect both structured shape data and a visual/screenshot representation; reason about spatial relationships; use typed/sanitized actions; keep a clear hierarchy; and perform a post-write visual lint pass. Prefer explicit node types, consistent geometry, directional connectors, readable labels, grouping, alignment and whitespace. For architecture/process diagrams, show dependencies and flow direction rather than decorative shapes. Use the smallest diagram that fully represents the planning graph.

External references: tldraw Agent Starter Kit and AI integration guidance; AgentsORG design-engineering diagram-design principles. Reuse concepts; do not copy proprietary code or unlicensed material.

## Layout invariants

- Check for overlapping elements after every write.
- Use uniform symmetric spacing.
- Never route arrows through shapes.
- Keep one clear visual hierarchy: Vision → target → goals → tasks.
- Do not duplicate canonical status into an independently editable data model.

## Required persistent metadata

\`visions\` stores the tldraw workspace, board and board URL.
\`vision_canvas_pages\` stores the overview and component page identities.
