import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { discoverRoutes } from "../scripts/route-discovery.mjs";

test("discovers app and pages routes while marking dynamic routes untested", async () => {
  const root = await mkdtemp(join(tmpdir(), "browser-routes-"));
  try {
    const files = [
      "src/app/page.tsx",
      "src/app/(marketing)/about/page.tsx",
      "pages/index.tsx",
      "pages/users/[id].tsx",
      "pages/api/health.ts"
    ];
    for (const file of files) {
      const path = join(root, file);
      await mkdir(path.slice(0, path.lastIndexOf("/")), { recursive: true });
      await writeFile(path, "export default function Page() { return null; }");
    }
    const routes = await discoverRoutes(root);
    assert.deepEqual(routes.map(route => route.path), ["/", "/about", "/users/[id]"]);
    assert.equal(routes.find(route => route.path === "/users/[id]").dynamic, true);
    assert.equal(routes.find(route => route.path === "/about").dynamic, false);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
