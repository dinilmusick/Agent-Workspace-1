import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import { isAbsolute, join, relative, resolve, sep } from "node:path";
import { discoverRoutes } from "./route-discovery.mjs";

const exists = path => access(path).then(() => true).catch(() => false);
const inside = (root, value) => {
  const path = resolve(root, value);
  const rel = relative(root, path);
  if (rel === ".." || rel.startsWith(".." + sep) || isAbsolute(rel)) {
    throw new Error("Browser manifest path escapes target repository: " + value);
  }
  return path;
};

export async function loadBrowserManifest() {
  const repositoryRoot = resolve(process.env.TARGET_ROOT ?? "workspaces/target", process.env.PROJECT_PATH ?? ".");
  const manifestPath = process.env.BROWSER_TEST_MANIFEST
    ? resolve(process.env.BROWSER_TEST_MANIFEST)
    : join(repositoryRoot, ".agent-workspace", "browser-tests.json");
  let manifest = {};
  if (await exists(manifestPath)) manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  if (manifest.version !== undefined && manifest.version !== 1) {
    throw new Error("Unsupported browser test manifest version: " + manifest.version);
  }

  const discovered = await discoverRoutes(repositoryRoot);
  const configured = Array.isArray(manifest.routes);
  const routes = configured ? manifest.routes : discovered.filter(route => !route.dynamic);
  const testedRoutes = routes.length ? routes : [{ name: "home", path: "/", source: "default-root" }];
  const untestedRoutes = discovered.filter(route => route.dynamic).map(route => ({
    ...route, reason: "Dynamic route requires a concrete path in browser-tests.json"
  }));
  const viewports = manifest.viewports ?? [
    { name: "desktop", width: 1440, height: 1000 },
    { name: "mobile", width: 390, height: 844 }
  ];
  const artifactsDir = resolve(process.env.ARTIFACT_DIR ?? "artifacts/browser");
  const visual = manifest.visual ?? {};
  const baselineDir = inside(repositoryRoot, visual.baselineDir ?? ".agent-workspace/visual-baselines");
  const authStates = {};
  for (const [name, state] of Object.entries(manifest.authStates ?? {})) {
    authStates[name] = {
      ...state,
      storageStatePath: state.storageState ? inside(repositoryRoot, state.storageState) : undefined
    };
    if (authStates[name].storageStatePath && !(await exists(authStates[name].storageStatePath))) {
      throw new Error("Auth state '" + name + "' does not exist: " + state.storageState);
    }
  }

  const result = {
    repositoryRoot, manifestPath, manifest, routes: testedRoutes, discoveredRoutes: discovered,
    untestedRoutes, viewports, authStates, artifactsDir, baselineDir,
    baseURL: process.env.TARGET_BASE_URL ?? manifest.baseUrl ?? "http://127.0.0.1:4173",
    accessibility: manifest.accessibility ?? { enabled: true, failOnViolations: false },
    visual: { enabled: visual.enabled === true, maxDiffPixelRatio: visual.maxDiffPixelRatio ?? 0.01 }
  };
  await mkdir(artifactsDir, { recursive: true });
  await writeFile(join(artifactsDir, "route-coverage.json"), JSON.stringify({
    evidenceKind: process.env.BROWSER_EVIDENCE_KIND ?? "real-target-preview",
    manifest: configured ? relative(repositoryRoot, manifestPath) : null,
    routeDiscovery: configured ? "manifest" : "framework-source",
    discoveredCount: discovered.length,
    testedRoutes: testedRoutes.map(({ path, name, source }) => ({ path, name, source })),
    untestedRoutes,
    note: discovered.length ? null : "No framework routes discovered; root route used. Configure routes explicitly for complete coverage."
  }, null, 2) + "\n");
  return result;
}
