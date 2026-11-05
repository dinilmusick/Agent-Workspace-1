#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'skipo-origin-validator-'));
for (const repo of ['Skipo','GutTS','Kloks','Luth','Aiko','Depm-Engine','Qwnsr-Engine','DocuStack-Engine','Srkl-Engine','Fod-Engine','Theta-Engine','Kult-Engine','Kelt-Engine']) {
  fs.mkdirSync(path.join(temp, repo), { recursive: true });
}
function write(repo, file, content) {
  const p = path.join(temp, repo, file);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, content);
}
write('Skipo','scaffolds/nextjs/.env.example','APP_URL=');
write('Skipo','scaffolds/vite/.env.example','APP_URL=');
write('Skipo','scaffolds/nextjs/src/config/env.ts','APP_URL');
write('Skipo','scaffolds/vite/src/config/env.ts','APP_URL');
write('GutTS','src/auth/luthAuthClient.ts','resolveRuntimeAppUrl APP_URL APPLICATION_ORIGIN_UNAVAILABLE');
write('GutTS','tests/luthAuthClient.test.ts','uses APP_URL when no browser exists');
write('Luth','src/backend/types.ts','APP_URL');
write('Luth','src/backend/auth/betterAuth.ts','getLuthBaseUrl baseURL: normalizedBaseUrl');
write('Luth','wrangler.jsonc','"APP_URL"');
write('Depm-Engine','.env.example','APP_URL=');
write('Srkl-Engine','.env.example','APP_URL=');
write('Depm-Engine','wrangler.toml','APP_URL');
for (const repo of ['Aiko','Qwnsr-Engine','DocuStack-Engine','Srkl-Engine','Fod-Engine','Theta-Engine','Kult-Engine','Kelt-Engine']) {
  write(repo,'.env.example','APP_URL=');
}
write('Depm-Engine','.env.example','APP_URL=');
const script = path.resolve(import.meta.dirname, '..', 'validate.mjs');
const run = spawnSync(process.execPath, [script, temp], { encoding: 'utf8' });
assert.equal(run.status, 0, run.stdout + run.stderr);
console.log('validator positive fixture: PASS');

fs.writeFileSync(path.join(temp, 'Depm-Engine', 'legacy.ts'), 'DEPM_GATEWAY_DOMAIN');
const negative = spawnSync(process.execPath, [script, temp], { encoding: 'utf8' });
assert.notEqual(negative.status, 0, negative.stdout + negative.stderr);
assert.match(negative.stdout, /DEPM_GATEWAY_DOMAIN/);
console.log('validator negative fixture: PASS');

write('Aiko','wrangler.toml','nodejs_compat_populate_process_env');
write('Qwnsr-Engine','wrangler.toml','nodejs_compat_populate_process_env');
write('DocuStack-Engine','wrangler.toml','nodejs_compat_populate_process_env');
write('Srkl-Engine','wrangler.toml','nodejs_compat_populate_process_env');
write('Fod-Engine','wrangler.toml','nodejs_compat_populate_process_env');
write('Kult-Engine','wrangler.toml','nodejs_compat_populate_process_env');
write('Kelt-Engine','wrangler.toml','nodejs_compat_populate_process_env');