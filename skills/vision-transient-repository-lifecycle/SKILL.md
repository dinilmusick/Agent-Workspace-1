# Vision transient repository lifecycle

## Contract

Every newly created Vision gets exactly one disposable **public** GitHub repository. The durable association and lifecycle state are stored in Supabase `public.vision_repositories`.

## Lifecycle

1. Create Vision with `vision_ledger_create`.
2. Call `vision_ledger_repository_spec(vision_id)`.
3. Create the returned `agentgpt-vision-<vision_key>` repository through ATAX `tools/github` first. Use the GitHub connector only as fallback.
4. Persist the association with `vision_ledger_associate_repository`.
5. Execute the Vision and independently verify linked Goals and descendant Tasks.
6. Mark deletion requested with `vision_ledger_mark_repository_deletion_requested`.
7. Delete the associated repository through the primary ATAX GitHub lifecycle path.
8. Independently verify the repository is absent (GitHub 404/not found).
9. Persist deletion evidence with `vision_ledger_mark_repository_deleted`.
10. Call `vision_ledger_finalize`.

## Hard gates

`vision_ledger_finalize` refuses completion when:
- the repository association is missing;
- the repository is not `deleted_verified`;
- the Vision has no linked Goal;
- any linked Goal is incomplete or has unverified descendant Tasks.

Repository deletion is therefore a **completion prerequisite**, not post-completion cleanup.

## Safety

Never associate or delete `dinilmusick/ATAX`; it is permanent substrate. Repository names are deterministic from `vision_key`. If a retry finds the repository already absent, independently verify the 404 and persist `deleted_verified`.

## Canonical state

Supabase is authoritative for Vision/repository lifecycle state. GitHub is authoritative for actual repository existence.
