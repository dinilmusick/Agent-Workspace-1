# Platform adapters

The canonical adapter entry point is `runner/platform_adapters.py`; provider-specific contracts, safety rules and examples are in [the Platform Development Adapters skill](../../skills/platform-adapters/SKILL.md).

The adapters are local-only:

- Cloudflare: `@cloudflare/vitest-plugin` executes Worker tests in Miniflare/workerd with Wrangler bindings.
- Vercel: local preview-environment builds and read-only inspection of an explicitly supplied preview deployment; no deploy/promote/redeploy commands.
- Supabase: local Postgres migrations and pgTAP tests only; no linked or remote DB and no Edge Runtime/Functions.

Run `python runner/platform_adapters.py all --project-path workspaces/target`. Results and provider logs are written to `artifacts/platforms/`.
