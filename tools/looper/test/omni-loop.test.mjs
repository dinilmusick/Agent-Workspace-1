import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";

const run = (args) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, ["tools/looper/looper.mjs", ...args], { cwd: process.cwd() });
  let stdout = "", stderr = "";
  child.stdout.on("data", (x) => { stdout += x; });
  child.stderr.on("data", (x) => { stderr += x; });
  child.on("error", reject);
  child.on("close", (code) => resolve({ code, stdout, stderr }));
});

test("Omni Loop accepts target + edit + behavior output and reaches verified pass", async () => {
  const dir = await mkdtemp(join(tmpdir(), "omni-loop-"));
  const contract = join(dir, "contract.json");
  const state = join(dir, "state.json");
  const iteration = join(dir, "iteration.json");
  const fixture = JSON.parse(await readFile("tools/looper/fixtures/omni-contract.json", "utf8"));
  await writeFile(contract, JSON.stringify(fixture, null, 2));
  let result = await run(["init", contract, state]);
  assert.equal(result.code, 0);
  await writeFile(iteration, JSON.stringify({
    input:{edit:{id:"edit-1"}},
    output:{behavior:{value:"expected"}},
    observation:{observed:true},
    criterionResults:[{criterionId:"behavior-correct",status:"satisfied",evidence:["test:passed"]}],
    toolsUsed:["tests"],evidence:["test:passed"],verdict:"pass",nextAction:null
  }, null, 2));
  result = await run(["record", state, iteration]);
  assert.equal(result.code, 0);
  const stateValue = JSON.parse(await readFile(state, "utf8"));
  assert.equal(stateValue.status, "completed");
  assert.equal(stateValue.history[0].input.edit.id, "edit-1");
});
