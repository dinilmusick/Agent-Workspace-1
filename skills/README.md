# Skill backup

`skills/` is the version-controlled mirror of the Supabase Skills Database.

- Each skill has its own `skills/<slug>/SKILL.md` file.
- `registry.json` indexes the catalogue; `current-versions.json` records the latest published versions for skills updated after the registry snapshot.
- `tool-bindings.json` mirrors the normalized tool registry and skill-to-tool associations.
- `optional-agent-bindings.json` records additional self-hosted/IDE agent backends that are not part of the default installed CLI set.
- `Loop Generator` uses `tools/looper/looper.mjs`; coding specialists can route to the shared TypeScript/React toolchain and optional agent runtimes.

Supabase remains the canonical source of truth. When a skill version or tool binding changes, publish the database version first and refresh this folder in the same implementation change. Preserve the Supabase skill ID, slug, version and tool slugs in every mirror.
