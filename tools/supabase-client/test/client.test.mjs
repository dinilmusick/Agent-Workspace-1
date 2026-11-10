import test from 'node:test';
import assert from 'node:assert/strict';
import { createSupabaseClient } from '../client.mjs';

function mockFetch(expected) {
  const calls = [];
  const fetchImpl = async (url, options = {}) => {
    calls.push({ url, options });
    const item = expected[calls.length - 1];
    assert.ok(item, `unexpected request #${calls.length}`);
    assert.equal(url, item.url);
    assert.equal(options.method ?? 'GET', item.method ?? 'GET');
    if (item.body !== undefined) assert.deepEqual(JSON.parse(options.body), item.body);
    return new Response(JSON.stringify(item.response ?? []), {
      status: item.status ?? 200,
      headers: { 'content-type': 'application/json' }
    });
  };
  return { fetchImpl, calls };
}

test('uses service-role auth and executes a semantic ledger RPC', async () => {
  const { fetchImpl, calls } = mockFetch([{
    url: 'https://example.supabase.co/rest/v1/rpc/goal_ledger_overview',
    method: 'POST',
    body: { goal_key_in: null },
    response: { goals: [] }
  }]);

  const client = createSupabaseClient({
    url: 'https://example.supabase.co/',
    serviceRoleKey: 'secret',
    fetchImpl
  });

  const result = await client.ledger.overview({ goal_key_in: null });
  assert.deepEqual(result, { goals: [] });
  assert.equal(calls[0].options.headers.apikey, 'secret');
  assert.equal(calls[0].options.headers.Authorization, 'Bearer secret');
});

test('provides skill search and rejects arbitrary tables', async () => {
  const { fetchImpl } = mockFetch([{
    url: 'https://example.supabase.co/rest/v1/skills?name=ilike.%25ledger%25&select=*&limit=5&order=name.asc',
    response: []
  }]);

  const client = createSupabaseClient({
    url: 'https://example.supabase.co',
    serviceRoleKey: 'secret',
    fetchImpl
  });

  await client.skills.search('ledger', { limit: 5 });
  await assert.rejects(() => client.tables.list('users'), /Table is not allowed/);
});

test('supports allowlisted CRUD routing', async () => {
  const { fetchImpl } = mockFetch([
    { url: 'https://example.supabase.co/rest/v1/tasks?status=eq.running&select=*', response: [] },
    { url: 'https://example.supabase.co/rest/v1/tasks?status=eq.running', method: 'PATCH', body: { current_step: 'verify' }, response: [] },
    { url: 'https://example.supabase.co/rest/v1/tasks?status=eq.running', method: 'DELETE', response: [] }
  ]);

  const client = createSupabaseClient({
    url: 'https://example.supabase.co',
    serviceRoleKey: 'secret',
    fetchImpl
  });

  await client.tables.list('tasks', { filters: { status: 'running' } });
  await client.tables.update('tasks', { status: 'running' }, { current_step: 'verify' });
  await client.tables.remove('tasks', { status: 'running' });
});
