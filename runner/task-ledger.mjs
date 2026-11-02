#!/usr/bin/env node
import { readFile } from "node:fs/promises";

const [action, ...args] = process.argv.slice(2);
if (!action) {
  console.error("Usage: node runner/task-ledger.mjs <action> [--payload JSON | --payload-file PATH]");
  process.exit(2);
}
const readArg = (name) => {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
};
const payloadText = readArg("--payload");
const payloadFile = readArg("--payload-file");
let payload = {};
try {
  if (payloadText) payload = JSON.parse(payloadText);
  else if (payloadFile) payload = JSON.parse(await readFile(payloadFile, "utf8"));
  if (!payload || Array.isArray(payload) || typeof payload !== "object") throw new Error("Payload must be a JSON object.");
} catch (error) {
  console.error(String(error));
  process.exit(2);
}
const base = (process.env.SUPABASE_URL ?? process.env.AGENT_TASK_LEDGER_URL)?.replace(/\/$/, "");
const apiKey = process.env.SUPABASE_ANON_KEY ?? process.env.AGENT_TASK_LEDGER_ANON_KEY;
const jwt = process.env.SUPABASE_AGENT_JWT ?? process.env.AGENT_TASK_LEDGER_JWT;
if (!base || !apiKey || !jwt) {
  console.error("Set SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_AGENT_JWT.");
  process.exit(2);
}
try {
  const response = await fetch(`${base}/functions/v1/task-ledger`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: apiKey,
      authorization: `Bearer ${jwt}`,
    },
    body: JSON.stringify({ action, payload }),
    signal: AbortSignal.timeout(30_000),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${JSON.stringify(body)}`);
  process.stdout.write(JSON.stringify(body, null, 2) + "\n");
} catch (error) {
  console.error(String(error));
  process.exit(1);
}
