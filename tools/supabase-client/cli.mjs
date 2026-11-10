#!/usr/bin/env node
import { createSupabaseClientFromEnv } from './client.mjs';

function usage() {
  console.error(`Usage:
  node tools/supabase-client/cli.mjs rpc <function> [json]
  node tools/supabase-client/cli.mjs ledger <command> [json]
  node tools/supabase-client/cli.mjs skills <list|search|get-by-name> [arg]
  node tools/supabase-client/cli.mjs table <select|insert|update|delete> <table> [json]

Environment:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
`);
  process.exit(2);
}

function jsonArg(value, fallback = {}) {
  if (value == null) return fallback;
  try { return JSON.parse(value); }
  catch (error) { throw new Error(`Invalid JSON argument: ${error.message}`); }
}

const [group, command, arg1, arg2] = process.argv.slice(2);
if (!group || !command) usage();

const client = createSupabaseClientFromEnv();
let result;

if (group === 'rpc') {
  result = await client.rpc(command, jsonArg(arg1));
} else if (group === 'ledger') {
  const methods = {
    overview: 'overview',
    'resume-by-key': 'resumeByKey',
    'claim-task-by-key': 'claimTaskByKey',
    'create-goal': 'createGoal',
    'update-goal': 'updateGoal',
    'create-task-tree': 'createTaskTree',
    heartbeat: 'heartbeat',
    'update-task': 'updateTask',
    'list-unfinished': 'listUnfinished'
  };
  const method = methods[command];
  if (!method) usage();
  result = await client.ledger[method](jsonArg(arg1));
} else if (group === 'skills') {
  if (command === 'list') result = await client.skills.list(jsonArg(arg1));
  else if (command === 'search') result = await client.skills.search(arg1 ?? '', jsonArg(arg2));
  else if (command === 'get-by-name') result = await client.skills.getByName(arg1);
  else usage();
} else if (group === 'table') {
  const value = jsonArg(arg2);
  if (command === 'select') result = await client.tables.list(arg1, { filters: value });
  else if (command === 'insert') result = await client.tables.insert(arg1, value);
  else if (command === 'update') {
    if (!Array.isArray(value) || value.length !== 2) throw new Error('table update expects [filters, patch].');
    result = await client.tables.update(arg1, value[0], value[1]);
  } else if (command === 'delete') result = await client.tables.remove(arg1, value);
  else usage();
} else usage();

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
