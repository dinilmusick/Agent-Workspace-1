import { chromium } from "playwright";
import { mkdir, writeFile } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";

const baseURL = process.env.TARGET_BASE_URL ?? "http://127.0.0.1:4173";
const outputDir = process.env.ARTIFACT_DIR ?? "artifacts/browser";
const diagnostics = { baseURL, startedAt: new Date().toISOString(), consoleErrors: [], pageErrors: [], requestFailures: [], httpErrors: [], pages: [] };
await mkdir(outputDir, { recursive: true });
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  page.on("console", message => { if (message.type() === "error") diagnostics.consoleErrors.push({ text: message.text(), location: message.location() }); });
  page.on("pageerror", error => diagnostics.pageErrors.push({ name: error.name, message: error.message, stack: error.stack }));
  page.on("requestfailed", request => diagnostics.requestFailures.push({ url: request.url(), method: request.method(), error: request.failure()?.errorText }));
  page.on("response", response => { if (response.status() >= 400) diagnostics.httpErrors.push({ url: response.url(), status: response.status(), statusText: response.statusText() }); });
  const response = await page.goto(baseURL, { waitUntil: "networkidle", timeout: 60000 }).catch(async error => { diagnostics.navigationError = error.message; return null; });
  diagnostics.navigationStatus = response?.status() ?? null;
  diagnostics.title = await page.title().catch(() => "");
  diagnostics.url = page.url();
  diagnostics.pages.push({ url: page.url(), title: diagnostics.title });
  await page.screenshot({ path: `${outputDir}/initial-page.png`, fullPage: true }).catch(error => { diagnostics.screenshotError = error.message; });
  const snapshot = await page.locator("body").innerText({ timeout: 10000 }).catch(error => `DOM text capture failed: ${error.message}`);
  await writeFile(`${outputDir}/dom.txt`, snapshot);
  await writeFile(`${outputDir}/diagnostics.json`, JSON.stringify(diagnostics, null, 2));
  const traceContext = page.context();
  await traceContext.tracing.start({ screenshots: true, snapshots: true, sources: true });
  await page.reload({ waitUntil: "domcontentloaded", timeout: 60000 }).catch(error => { diagnostics.reloadError = error.message; });
  await traceContext.tracing.stop({ path: `${outputDir}/trace.zip` });
  await writeFile(`${outputDir}/diagnostics.json`, JSON.stringify({ ...diagnostics, completedAt: new Date().toISOString() }, null, 2));
  const failures = diagnostics.consoleErrors.length + diagnostics.pageErrors.length + diagnostics.requestFailures.length + diagnostics.httpErrors.length;
  console.log(JSON.stringify({ navigationStatus: diagnostics.navigationStatus, title: diagnostics.title, diagnosticCount: failures, outputDir }, null, 2));
  if (!response || !response.ok() || failures > 0) process.exitCode = 1;
} finally {
  await browser.close();
}
