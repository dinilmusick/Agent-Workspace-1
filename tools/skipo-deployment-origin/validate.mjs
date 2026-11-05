#!/usr/bin/env node
/**
 * Deterministic post-change validator for the Skipo deployment-origin contract.
 *
 * Usage:
 *   node tools/skipo-deployment-origin/validate.mjs <workspace-root>
 */

import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || '.');

const repos = [
  'Skipo','GutTS','Kloks','Luth','Aiko','Depm-Engine','Qwnsr-Engine',
  'DocuStack-Engine','Srkl-Engine','Fod-Engine','Theta-Engine','Kult-Engine','Kelt-Engine',
];
const sourceExtensions = new Set(['.ts','.tsx','.js','.jsx','.mjs','.cjs','.json','.jsonc','.toml','.yaml','.yml','.md']);

function locate(repo) {
  return [
    path.join(root, repo),
    path.join(root, 'clones', `dinilmusick__${repo}`),
    path.join(root, 'clones', repo),
  ].find((p) => fs.existsSync(p));
}

function read(repo, file) {
  const base = locate(repo);
  if (!base) return '';
  const p = path.join(base, file);
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '';
}

function walk(base) {
  const files = [];
  if (!base) return files;
  const visit = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (['node_modules','.git','dist','build','.next','coverage','.aistudio'].includes(entry.name)) continue;
      const target = path.join(dir, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (sourceExtensions.has(path.extname(entry.name).toLowerCase())) files.push(target);
    }
  };
  visit(base);
  return files;
}

function requireText(repo, file, needle, label) {
  const content = read(repo, file);
  if (!content.includes(needle)) failures.push(`${repo}/${file}: missing ${label || needle}`);
}

function forbidText(repo, file, needle, label) {
  const content = read(repo, file);
  if (content.includes(needle)) failures.push(`${repo}/${file}: forbidden ${label || needle}`);
}

function requireAnywhere(repo, needle, label) {
  const base = locate(repo);
  if (!base) return;
  const found = walk(base).some((file) => fs.readFileSync(file, 'utf8').includes(needle));
  if (!found) failures.push(`${repo}: missing ${label || needle} in repository`);
}

function forbidAnywhere(repo, needle, label) {
  const base = locate(repo);
  if (!base) return;
  for (const file of walk(base)) {
    if (fs.readFileSync(file, 'utf8').includes(needle)) {
      failures.push(`${repo}/${path.relative(base, file)}: forbidden ${label || needle}`);
    }
  }
}

const failures = [];
const missing = [];

for (const repo of repos) if (!locate(repo)) missing.push(repo);

// Canonical Skipo scaffold contract.
forbidAnywhere('Skipo','DEPM_GATEWAY_DOMAIN','legacy scaffold deployment variable');
requireText('Skipo','scaffolds/nextjs/.env.example','APP_URL','Next.js APP_URL');
requireText('Skipo','scaffolds/vite/.env.example','APP_URL','Vite APP_URL');
requireText('Skipo','scaffolds/nextjs/src/config/env.ts','APP_URL','Next.js typed APP_URL');
requireText('Skipo','scaffolds/vite/src/config/env.ts','APP_URL','Vite typed APP_URL');
for (const variant of ['nextjs','vite']) {
  const client = read('Skipo',`scaffolds/${variant}/src/libraries/client/luthAuthClient.ts`);
  if (client.includes('origin: typeof window')) failures.push(`Skipo/${variant}: browser-only origin discovery remains in scaffold client`);
}

// Canonical GutTS resolver.
requireText('GutTS','src/auth/luthAuthClient.ts','resolveRuntimeAppUrl','runtime APP_URL resolver');
requireText('GutTS','src/auth/luthAuthClient.ts','APP_URL','APP_URL runtime environment');
requireText('GutTS','src/auth/luthAuthClient.ts','APPLICATION_ORIGIN_UNAVAILABLE','observable missing-origin failure');
requireText('GutTS','tests/luthAuthClient.test.ts','uses APP_URL when no browser exists','non-browser APP_URL test');

// Luth authority.
requireText('Luth','src/backend/types.ts','APP_URL','Luth APP_URL binding');
requireText('Luth','src/backend/auth/betterAuth.ts','getLuthBaseUrl','canonical APP_URL baseURL resolver');
requireText('Luth','src/backend/auth/betterAuth.ts','baseURL: normalizedBaseUrl','Better Auth baseURL');
requireText('Luth','wrangler.jsonc','"APP_URL"','Cloudflare APP_URL binding');
for (const legacy of ['BETTER_AUTH_URL','BETTER_AUTH_SECRET','GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET','LUTH_ALLOWED_ORIGINS']) {
  forbidText('Luth','wrangler.jsonc',legacy,`legacy runtime binding ${legacy}`);
}

// DEPM migration.
requireText('Depm-Engine','.env.example','APP_URL','DEPM APP_URL');
requireText('Depm-Engine','wrangler.toml','APP_URL','DEPM APP_URL binding');
forbidAnywhere('Depm-Engine','DEPM_GATEWAY_DOMAIN','legacy DEPM gateway variable');
forbidAnywhere('Srkl-Engine','SRKL_PUBLIC_URL','legacy SRKL deployment variable');

// Every client repository must carry APP_URL and no Luth URL as its application origin.
for (const repo of repos.filter((r) => !['Skipo','GutTS','Kloks','Luth'].includes(r))) {
  requireAnywhere(repo,'APP_URL','APP_URL contract');
}
for (const repo of ['Aiko','Qwnsr-Engine','DocuStack-Engine','Srkl-Engine','Fod-Engine','Kult-Engine','Kelt-Engine']) {
  requireText(repo,'wrangler.toml','nodejs_compat_populate_process_env','Worker APP_URL runtime environment bridge');
}
for (const repo of ['Aiko','Qwnsr-Engine','DocuStack-Engine','Srkl-Engine','Fod-Engine','Theta-Engine','Kult-Engine','Kelt-Engine']) {
  forbidAnywhere(repo,'origin: baseUrl','Luth authority incorrectly used as application origin');
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
