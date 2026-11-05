#!/usr/bin/env node
/**
 * Deterministic post-change validator for the Skipo deployment-origin contract.
 *
 * Usage:
 *   node tools/skipo-deployment-origin/validate.mjs <workspace-root>
 *
 * <workspace-root> must contain repositories either directly by name
 * (Luth, Skipo, GutTS, ...) or under clones/dinilmusick__<Repo>.
 */

import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || '.');

const repos = [
  'Skipo','GutTS','Kloks','Luth','Aiko','Depm-Engine','Qwnsr-Engine',
  'DocuStack-Engine','Srkl-Engine','Fod-Engine','Theta-Engine','Kult-Engine','Kelt-Engine',
];

function locate(repo) {
  const candidates = [
    path.join(root, repo),
    path.join(root, 'clones', `dinilmusick__${repo}`),
    path.join(root, 'clones', repo),
  ];
  return candidates.find((p) => fs.existsSync(p));
}

function read(repo, file) {
  const base = locate(repo);
  if (!base) return '';
  const p = path.join(base, file);
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '';
}

function requireText(repo, file, needle, label) {
  const content = read(repo, file);
  if (!content.includes(needle)) failures.push(`${repo}/${file}: missing ${label || needle}`);
}

function forbidText(repo, file, needle, label) {
  const content = read(repo, file);
  if (content.includes(needle)) failures.push(`${repo}/${file}: forbidden ${label || needle}`);
}

const failures = [];
const missing = [];

for (const repo of repos) if (!locate(repo)) missing.push(repo);

requireText('Skipo','scaffolds/nextjs/.env.example','APP_URL','APP_URL');
requireText('Skipo','scaffolds/vite/.env.example','APP_URL','APP_URL');
requireText('Skipo','scaffolds/nextjs/src/config/env.ts','APP_URL','typed APP_URL');
requireText('Skipo','scaffolds/vite/src/config/env.ts','APP_URL','typed APP_URL');

requireText('GutTS','src/auth/luthAuthClient.ts','APP_URL','non-browser APP_URL fallback');
requireText('GutTS','tests/luthAuthClient.test.ts','APP_URL','APP_URL test coverage');

requireText('Luth','src/backend/types.ts','APP_URL','Luth APP_URL binding');
requireText('Luth','src/backend/auth/betterAuth.ts','baseURL','Better Auth baseURL');
requireText('Luth','wrangler.jsonc','APP_URL','Cloudflare APP_URL binding');

forbidText('Luth','src/backend/auth/betterAuth.ts','BETTER_AUTH_URL','legacy Better Auth URL authority');
forbidText('Luth','src/backend/auth/betterAuth.ts','BETTER_AUTH_SECRET','legacy Better Auth secret authority');
forbidText('Luth','src/backend/auth/betterAuth.ts','GOOGLE_CLIENT_ID','legacy Google credential authority');
forbidText('Luth','src/backend/auth/betterAuth.ts','GOOGLE_CLIENT_SECRET','legacy Google credential authority');

requireText('Depm-Engine','.env.example','APP_URL','APP_URL');
forbidText('Depm-Engine','.env.example','DEPM_GATEWAY_DOMAIN','legacy gateway variable');
forbidText('Depm-Engine','wrangler.toml','DEPM_GATEWAY_DOMAIN','legacy gateway variable');

for (const repo of repos.filter((r) => !['Skipo','GutTS','Kloks','Luth'].includes(r))) {
  requireText(repo,'.env.example','APP_URL','APP_URL');
}

const result = {
  root,
  located: repos.filter((r) => locate(r)),
  missing,
  failures,
  passed: missing.length === 0 && failures.length === 0,
};

console.log(JSON.stringify(result, null, 2));
process.exit(result.passed ? 0 : 1);
