export function trackBrowser(page) {
  const report = { consoleErrors: [], pageErrors: [], requestFailures: [], httpErrors: [] };
  page.on("console", message => {
    if (message.type() === "error") report.consoleErrors.push({ text: message.text(), location: message.location() });
  });
  page.on("pageerror", error => report.pageErrors.push({ name: error.name, message: error.message }));
  page.on("requestfailed", request => report.requestFailures.push({
    url: request.url(), method: request.method(), error: request.failure()?.errorText
  }));
  page.on("response", response => {
    if (response.status() >= 400) report.httpErrors.push({
      url: response.url(), status: response.status(), statusText: response.statusText()
    });
  });
  return report;
}

export async function attachBrowserEvidence(page, report, testInfo) {
  const dom = await page.locator("html").evaluate(element => element.outerHTML).catch(error => "DOM snapshot unavailable: " + error.message);
  await testInfo.attach("dom-snapshot.html", { body: dom, contentType: "text/html" });
  await testInfo.attach("browser-diagnostics", {
    body: JSON.stringify(report, null, 2), contentType: "application/json"
  });
  try {
    await testInfo.attach("page-screenshot", {
      body: await page.screenshot({ fullPage: true }), contentType: "image/png"
    });
  } catch (error) {
    report.screenshotError = error.message;
    await testInfo.attach("browser-diagnostics-final", {
      body: JSON.stringify(report, null, 2), contentType: "application/json"
    });
  }
}

export function assertRuntimeClean(report, expect, ignore = []) {
  const ignored = value => ignore.some(pattern => value.includes(pattern));
  const failures = [
    ...report.consoleErrors.map(item => "console: " + item.text),
    ...report.pageErrors.map(item => "page: " + item.message),
    ...report.requestFailures.map(item => "request: " + item.url + " (" + item.error + ")"),
    ...report.httpErrors.map(item => "HTTP " + item.status + ": " + item.url)
  ].filter(value => !ignored(value));
  expect(failures, "Unexpected browser console, page, network or HTTP failures").toEqual([]);
}
