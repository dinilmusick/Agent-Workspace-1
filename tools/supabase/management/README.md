# Supabase management tool

The existing connector-less Supabase management implementation remains at tools/supabase-agent-client/ for backwards compatibility.

Use it when an agent needs runtime CRUD, RPC, AgentGPT ledger, or skill-registry access to an already provisioned Supabase project.

Substrate provisioning is deliberately separate under tools/supabase/substrate/.

Credentials are runtime-only; never commit them.