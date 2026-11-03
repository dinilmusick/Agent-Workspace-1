---
name: "tldraw Agent"
slug: tldraw-agent
version: 1.0.0
status: active
---

# tldraw Agent

Agent-oriented canvas manipulation and visual verification.

## Purpose
Give agents a disciplined method for reading, creating and revising tldraw diagrams rather than treating a canvas as a blind drawing surface.

## Contract
- Read the user's request, current selection, visible canvas and relevant structured shapes.
- Maintain explicit typed actions for create/update/delete and higher-level layout operations.
- Keep spatial context: coordinates, bounds, clusters and relationships matter.
- After mutations, inspect the resulting visual state and correct layout defects.
- For persistent Visions, mirror Supabase's Vision → target → goal → task hierarchy exactly; Supabase remains canonical.
- Use comments/annotations as localized review context when available.

## Diagram loop
UNDERSTAND → MODEL → DRAW → INSPECT → LINT → REVISE → VERIFY.

## Official reference
The tldraw Agent Starter Kit documents typed canvas actions, screenshots plus structured shape context, layout operations, todo tracking and iterative agent loops. The tldraw AI integration documentation documents direct agent control and visual/structured context.

## Boundaries
Do not invent board IDs, pages or canonical state. Do not store planning truth only on the canvas. Do not copy external implementation code into this repository unless its license and repository policy permit it.
