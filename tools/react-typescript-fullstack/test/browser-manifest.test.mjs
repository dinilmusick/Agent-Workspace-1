import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadBrowserManifest } from "../scripts/browser-manifest.mjs";

const envKeys = ["TARGET_ROOT", "PROJECT_PATH", "BROWSER_TEST_MANIFEST", "ARTIFACT_DIR", "TARGET_BASE_URL", "BROWSER_EVIDENCE_KIND"];
const saveEnv = () => Object.fromEntries(envKeys.map(key => [key, process.env[key]]));
const restoreEnv = saved => envKeys.forEach(key => {
  if (saved[key] === undefined) delete process.env[key];
  else process.env[key] = saved[key];
});

test("loads explicit routes and reports dynamic framework routes as untested", async () => {
  const saved = saveEnv();
  const root = await mkdtemp(join(tmpdir(), "browser-manifest-"));
  try {
    await mkdir(join(root, ".agent-workspace"), { recursive: true });
    await mkdir(join(root, "src/app/[slug]"), { recursive: true });
    await mkdir(join(root, "src/app/about"), { recursive: true });
    await writeFile(join(root, "src/app/[slug]/page.tsx"), "export default function Page() { return null; }");
    await writeFile(join(root, "src/app/about/page.tsx"), "export default function Page() { return null; }");
    await writeFile(join(root, ".agent-workspace/browser-tests.json"), JSON.stringify({
      version: 1,
      routes: [{ name: "home", path: "/" }],
      viewports: [{ name: "desktop", width: 1280, height: 800 }]
    }));
    process.env.TARGET_ROOT = root;
    delete process.env.PROJECT_PATH;
    delete process.env.BROWSER_TEST_MANIFEST;
    process.env.ARTIFACT_DIR = join(root, "artifacts");
    process.env.TARGET_BASE_URL = "http://127.0.0.1:4173";
    process.env.BROWSER_EVIDENCE_KIND = "fixture-unit-test";
    const result = await loadBrowserManifest();
    assert.equal(result.routes.length, 1);
    assert.deepEqual(result.untestedRoutes.map(route => route.path).sort(), ["/[slug]", "/about"]);
    const coverage = JSON.parse(await readFile(join(root, "artifacts/route-coverage.json"), "utf8"));
    assert.equal(coverage.routeDiscovery, "manifest");
    assert.equal(coverage.untestedRoutes.length, 2);
    assert.equal(coverage.evidenceKind, "fixture-unit-test");
  } finally {
    restoreEnv(saved);
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects a project path that escapes the checked-out target", async () => {
  const saved = saveEnv();
  const root = await mkdtemp(join(tmpdir(), "browser-manifest-"));
  try {
    process.env.TARGET_ROOT = root;
    process.env.PROJECT_PATH = "../outside";
    process.env.ARTIFACT_DIR = join(root, "artifacts");
    await assert.rejects(loadBrowserManifest(), /escapes target repository/);
  } finally {
    restoreEnv(saved);
    await rm(root, { recursive: true, force: true });
  }
});
