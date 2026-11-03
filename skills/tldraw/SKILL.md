---
name: "tldraw"
slug: tldraw
version: 1.1.0
source: Supabase Skills Database
sourceId: 1
status: active
---

# tldraw

Use tldraw as the visual projection layer for Vision decomposition, not as the source of truth.

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

## Layout invariants

- Check for overlapping elements after every write.
- Use uniform symmetric spacing.
- Never route arrows through shapes.
- Keep one clear visual hierarchy: Vision → target → goals → tasks.
- Do not duplicate canonical status into an independently editable data model.

## Required persistent metadata

\`visions\` stores the tldraw workspace, board and board URL.
\`vision_canvas_pages\` stores the overview and component page identities.
