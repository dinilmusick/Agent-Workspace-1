import { readdir } from "node:fs/promises";
import { join, relative, sep } from "node:path";

const extensions = /\.(?:js|jsx|ts|tsx|mjs|cjs)$/;
const pageFile = /^page\.(?:js|jsx|ts|tsx|mjs|cjs)$/;
const ignored = new Set(["api", "__tests__", "__test__", "node_modules"]);

function routePath(root, file, router) {
  const parts = relative(root, file).split(sep);
  const filename = parts.pop().replace(extensions, "");
  if (router === "pages" && filename !== "index") parts.push(filename);
  const clean = parts.filter(part => !/^\(.*\)$/.test(part) && !part.startsWith("@"));
  const dynamic = clean.some(part => /^\[.+\]$/.test(part));
  return { path: ("/" + clean.join("/")).replace(/\/$/, "") || "/", dynamic };
}

async function walk(root, directory, router, routes) {
  let entries;
  try { entries = await readdir(directory, { withFileTypes: true }); }
  catch (error) { if (error.code === "ENOENT") return; throw error; }
  for (const entry of entries) {
    if (entry.isDirectory()) {
      if (!ignored.has(entry.name) && !entry.name.startsWith("_")) {
        await walk(root, join(directory, entry.name), router, routes);
      }
      continue;
    }
    const isRoute = router === "app"
      ? pageFile.test(entry.name)
      : extensions.test(entry.name) && !/^_(?:app|document|error)\./.test(entry.name);
    if (!isRoute) continue;
    const file = join(directory, entry.name);
    const route = routePath(root, file, router);
    routes.set(route.path, { ...route, source: relative(root, file) });
  }
}

export async function discoverRoutes(projectRoot) {
  const routes = new Map();
  for (const router of ["app", "pages"]) {
    for (const root of [join(projectRoot, router), join(projectRoot, "src", router)]) {
      await walk(root, root, router, routes);
    }
  }
  return [...routes.values()].sort((a, b) => a.path.localeCompare(b.path));
}
