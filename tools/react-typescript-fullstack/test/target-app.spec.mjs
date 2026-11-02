import { test as base, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { loadBrowserManifest } from "../scripts/browser-manifest.mjs";
import { assertRuntimeClean, attachBrowserEvidence, trackBrowser } from "../scripts/browser-evidence.mjs";

const browser = await loadBrowserManifest();
const test = base.extend({
  page: async ({ page }, use, testInfo) => {
    const report = trackBrowser(page);
    await use(page);
    await attachBrowserEvidence(page, report, testInfo);
    if (browser.manifest.failOnRuntimeErrors !== false) {
      assertRuntimeClean(report, expect, browser.manifest.ignoreRuntimeErrors ?? []);
    }
  }
});

const slug = value => String(value ?? "route").replace(/[^a-z0-9_-]+/gi, "-").replace(/^-|-$/g, "");
const locatorFor = (page, selector) => page.locator(selector);

for (const route of browser.routes) {
  for (const viewport of browser.viewports) {
    test("route " + route.path + " at " + viewport.name, async ({ page }, testInfo) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      const response = await page.goto(route.path, { waitUntil: "networkidle" });
      expect(response?.ok(), "Route did not return a successful response: " + route.path).toBeTruthy();
      if (route.expect?.title) await expect(page).toHaveTitle(route.expect.title);
      if (route.expect?.heading) await expect(page.getByRole("heading", { name: route.expect.heading })).toBeVisible();
      for (const selector of route.expect?.visible ?? []) await expect(locatorFor(page, selector)).toBeVisible();

      if (browser.accessibility.enabled !== false) {
        const axe = await new AxeBuilder({ page }).withTags(
          browser.accessibility.tags ?? ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]
        ).analyze();
        await testInfo.attach("axe-accessibility.json", {
          body: JSON.stringify({ violations: axe.violations, passes: axe.passes.length, incomplete: axe.incomplete.length }, null, 2),
          contentType: "application/json"
        });
        if (browser.accessibility.failOnViolations === true) {
          expect(axe.violations.map(item => ({ id: item.id, impact: item.impact, nodes: item.nodes.length }))).toEqual([]);
        }
      }
      if (browser.visual.enabled) {
        await expect(page).toHaveScreenshot(["routes", slug(route.name ?? route.path) + "-" + slug(viewport.name) + ".png"], {
          maxDiffPixelRatio: browser.visual.maxDiffPixelRatio
        });
      }
    });
  }
}

for (const flow of browser.manifest.workflows ?? []) {
  test("workflow " + flow.name, async ({ browser: engine }, testInfo) => {
    const auth = flow.authState ? browser.authStates[flow.authState] : undefined;
    if (flow.authState && !auth) throw new Error("Unknown auth state '" + flow.authState + "' in workflow '" + flow.name + "'");
    const context = await engine.newContext({
      baseURL: browser.baseURL,
      storageState: auth?.storageStatePath,
      viewport: flow.viewport ?? browser.viewports[0]
    });
    const page = await context.newPage();
    const report = trackBrowser(page);
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    try {
      for (const step of flow.steps ?? []) {
        const locator = step.selector ? locatorFor(page, step.selector) : null;
        switch (step.action) {
          case "navigate": await page.goto(step.path, { waitUntil: "networkidle" }); break;
          case "click": await locator.click(); break;
          case "fill": await locator.fill(step.value); break;
          case "check": await locator.check(); break;
          case "uncheck": await locator.uncheck(); break;
          case "selectOption": await locator.selectOption(step.value); break;
          case "expectVisible": await expect(locator).toBeVisible(); break;
          case "expectHidden": await expect(locator).toBeHidden(); break;
          case "expectText": await expect(locator).toContainText(step.value); break;
          case "expectUrl": await expect(page).toHaveURL(new RegExp(step.value)); break;
          case "expectEnabled": await expect(locator).toBeEnabled(); break;
          default: throw new Error("Unsupported workflow action '" + step.action + "'");
        }
      }
    } finally {
      await attachBrowserEvidence(page, report, testInfo);
      const tracePath = testInfo.outputPath("workflow-trace.zip");
      await context.tracing.stop({ path: tracePath });
      await context.close();
      await testInfo.attach("workflow-trace", { path: tracePath, contentType: "application/zip" });
    }
    if (browser.manifest.failOnRuntimeErrors !== false) {
      assertRuntimeClean(report, expect, browser.manifest.ignoreRuntimeErrors ?? []);
    }
  });
}
