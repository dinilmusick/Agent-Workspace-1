# Ephemeral-agent lease and heartbeat protocol

The Task Ledger treats worker ownership as a short heartbeat lease.

## Policy

- Workers checkpoint every ~2 minutes while actively executing.
- Workers independently verify ownership about every 5 minutes.
- A running task is reclaimable after **5 minutes without a valid heartbeat**.
- \`claim_token\` is the fencing token. Lease expiry alone never grants recovery.
- A recovery rotates the fencing token, increments \`attempt_count\`, preserves the previous heartbeat checkpoint, and appends \`lease_recovered\`.
- A worker that discovers fencing loss must stop. It may append a \`handoff\` event containing its final note; it must not overwrite canonical task ownership or progress.
- The next worker reads task state and append-only events before continuing.

## Durable heartbeat checkpoint

Every heartbeat writes:

- \`current_step\`
- \`heartbeat_context.activity\`
- \`heartbeat_context.progress\`
- \`heartbeat_context.discoveries\`
- \`heartbeat_context.blockers\`
- \`heartbeat_context.next_action\`

The same context is copied into the heartbeat event and preserved in a \`lease_recovered\` event when another worker takes over.

## Worker loop

\`\`\`text
claim → work → checkpoint/heartbeat → ownership check → continue
                         │                    │
                         │                    └─ lost → handoff event → stop
                         │
                         └─ no heartbeat for 5m → another agent may claim
\`\`\`

The 5-minute value is the crash/failover threshold, not the normal heartbeat interval. The shorter heartbeat interval provides margin for transient failures.
