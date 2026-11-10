const DEFAULT_TABLES = new Set([
  'goals','goal_versions','goal_events','goal_iterations',
  'tasks','task_events','task_dependencies','task_iterations',
  'skills','skill_versions','skill_tools','skill_tool_links',
  'agents','obstacles','evidence','ownership','heartbeats'
]);

export function createSupabaseClient({
  url = process.env.SUPABASE_URL,
  serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY,
  fetchImpl = globalThis.fetch,
  allowedTables = DEFAULT_TABLES
} = {}) {
  if (!url) throw new Error('Missing Supabase URL. Set SUPABASE_URL.');
  if (!serviceRoleKey) throw new Error('Missing Supabase service-role key. Set SUPABASE_SERVICE_ROLE_KEY.');
  if (typeof fetchImpl !== 'function') throw new Error('A fetch implementation is required.');

  const base = url.replace(/\/$/, '');
  const headers = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    'Content-Type': 'application/json'
  };

  async function request(path, options = {}) {
    const response = await fetchImpl(`${base}${path}`, {
      ...options,
      headers: { ...headers, ...(options.headers ?? {}) }
    });
    const text = await response.text();
    let body;
    try { body = text ? JSON.parse(text) : null; } catch { body = text; }
    if (!response.ok) {
      const detail = typeof body === 'string' ? body : JSON.stringify(body);
      throw new Error(`Supabase request failed (${response.status}): ${detail}`);
    }
    return body;
  }

  function tableName(table) {
    if (!allowedTables.has(table)) throw new Error(`Table is not allowed: ${table}`);
    return table;
  }

  function encodeQuery(filters = {}) {
    const query = new URLSearchParams();
    for (const [column, condition] of Object.entries(filters)) {
      if (typeof condition === 'string') {
        query.set(column, `eq.${condition}`);
        continue;
      }
      if (!condition || typeof condition !== 'object' || Array.isArray(condition)) {
        throw new Error(`Invalid filter for ${column}`);
      }
      const { op, value } = condition;
      if (!['eq','neq','gt','gte','lt','lte','like','ilike','is','in'].includes(op)) {
        throw new Error(`Unsupported filter operator: ${op}`);
      }
      query.set(column, `${op}.${Array.isArray(value) ? `(${value.join(',')})` : value}`);
    }
    return query;
  }

  const api = {
    async rpc(functionName, args = {}) {
      if (!/^\w+$/.test(functionName)) throw new Error('RPC function name must be a simple identifier.');
      return request(`/rest/v1/rpc/${encodeURIComponent(functionName)}`, {
        method: 'POST',
        body: JSON.stringify(args)
      });
    },

    async select(table, { filters = {}, columns = '*', limit, order } = {}) {
      const query = encodeQuery(filters);
      query.set('select', columns);
      if (limit != null) query.set('limit', String(limit));
      if (order) query.set('order', order);
      return request(`/rest/v1/${tableName(table)}?${query}`);
    },

    async insert(table, rows, { returning = 'representation' } = {}) {
      if (!Array.isArray(rows) || rows.length === 0) throw new Error('insert requires a non-empty array of rows.');
      return request(`/rest/v1/${tableName(table)}`, {
        method: 'POST',
        headers: { Prefer: `return=${returning}` },
        body: JSON.stringify(rows)
      });
    },

    async update(table, filters, patch, { returning = 'representation' } = {}) {
      if (!patch || typeof patch !== 'object' || Array.isArray(patch)) throw new Error('update requires an object patch.');
      const query = encodeQuery(filters);
      return request(`/rest/v1/${tableName(table)}?${query}`, {
        method: 'PATCH',
        headers: { Prefer: `return=${returning}` },
        body: JSON.stringify(patch)
      });
    },

    async remove(table, filters, { returning = 'representation' } = {}) {
      const query = encodeQuery(filters);
      return request(`/rest/v1/${tableName(table)}?${query}`, {
        method: 'DELETE',
        headers: { Prefer: `return=${returning}` }
      });
    },

    ledger: {
      overview: (args = {}) => api.rpc('goal_ledger_overview', args),
      resumeByKey: (args = {}) => api.rpc('goal_ledger_resume_by_key', args),
      claimTaskByKey: (args = {}) => api.rpc('goal_ledger_claim_task_by_key', args),
      createGoal: (args = {}) => api.rpc('goal_ledger_create', args),
      updateGoal: (args = {}) => api.rpc('goal_ledger_update', args),
      createTaskTree: (args = {}) => api.rpc('task_ledger_create_tree', args),
      heartbeat: (args = {}) => api.rpc('task_ledger_heartbeat', args),
      updateTask: (args = {}) => api.rpc('task_ledger_update', args),
      listUnfinished: (args = {}) => api.rpc('goal_ledger_list_unfinished', args)
    },

    skills: {
      list: (options = {}) => api.select('skills', options),
      getByName: (name) => api.select('skills', { filters: { name }, limit: 1 }),
      search: (term, { limit = 20 } = {}) => api.select('skills', {
        filters: { name: { op: 'ilike', value: `%${term}%` } },
        limit,
        order: 'name.asc'
      }),
      versions: (options = {}) => api.select('skill_versions', options),
      tools: (options = {}) => api.select('skill_tools', options),
      links: (options = {}) => api.select('skill_tool_links', options)
    },

    tables: {
      list: (table, options = {}) => api.select(table, options),
      insert: (table, rows, options = {}) => api.insert(table, rows, options),
      update: (table, filters, patch, options = {}) => api.update(table, filters, patch, options),
      remove: (table, filters, options = {}) => api.remove(table, filters, options)
    }
  };

  return api;
}

export function createSupabaseClientFromEnv(options = {}) {
  return createSupabaseClient({
    url: process.env.SUPABASE_URL,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    ...options
  });
}
