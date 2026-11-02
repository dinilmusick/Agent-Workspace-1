import { defineConfig } from "@playwright/test";
import { join, resolve } from "node:path";
import { loadBrowserManifest } from "./scripts/browser-manifest.mjs";

const browser = await loadBrowserManifest();
const baselineDir = browser.visual.enabled
  ? browser.baselineDir
  : join(browser.artifactsDir, "visual-baselines");

export default defineConfig({
  testDir: "./test",
  testMatch: "target-app.spec.mjs",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: [["list"], ["json", { outputFile: join(browser.artifactsDir, "playwright-report.json") }]],
  outputDir: join(browser.artifactsDir, "test-results"),
  snapshotPathTemplate: resolve(baselineDir, "{testFilePath}", "{arg}{ext}"),
  updateSnapshots: process.env.UPDATE_VISUAL_BASELINES === "1" ? "all" : "none",
  use: {
    baseURL: browser.baseURL,
    browserName: "chromium",
    actionTimeout: 10000,
    navigationTimeout: 60000,
    screenshot: "only-on-failure",
    trace: "on",
    video: "retain-on-failure"
  }
});
