import test from "node:test";
import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";

const packagePath = new URL("../package.json", import.meta.url);
const canonicalInspector = new URL("../scripts/inspect-browser.mjs", import.meta.url);
const legacyInspector = new URL("../scripts/inspect.mjs", import.meta.url);

test("React toolchain inspect command resolves to the canonical browser inspector", async () => {
  const manifest = JSON.parse(await readFile(packagePath, "utf8"));
  assert.equal(manifest.scripts.inspect, "node scripts/inspect-browser.mjs");
  await access(canonicalInspector);
  await assert.rejects(access(legacyInspector), { code: "ENOENT" });
});

test("canonical inspector remains syntax-valid JavaScript", () => {
  const result = spawnSync(process.execPath, ["--check", canonicalInspector.pathname], {
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
});
