import { describe, expect, it } from "vitest";
import { authorize, normalizePath, resolvePage, SESSION_TOKEN, validateCredentials } from "../../../../examples/quality-sample/app.mjs";

describe("quality sample application", () => {
  it("normalizes local paths, queries and trailing slashes", () => {
    expect(normalizePath("/")).toBe("/");
    expect(normalizePath("/about/?tab=security")).toBe("/about");
    expect(normalizePath(undefined)).toBe("/");
  });

  it("accepts only the configured test credentials", () => {
    expect(validateCredentials({ email: "qa@example.com", password: "quality-test" })).toBe(true);
    expect(validateCredentials({ email: "wrong@example.com", password: "quality-test" })).toBe(false);
    expect(validateCredentials({ email: "qa@example.com", password: "wrong" })).toBe(false);
    expect(validateCredentials(null)).toBe(false);
    expect(validateCredentials([])).toBe(false);
  });

  it("distinguishes anonymous, forbidden and authenticated sessions", () => {
    expect(authorize("").status).toBe(401);
    expect(authorize("invalid-session").status).toBe(403);
    expect(authorize(SESSION_TOKEN)).toEqual({ allowed: true, status: 200 });
  });

  it("resolves public, protected and missing pages", () => {
    expect(resolvePage("/").status).toBe(200);
    expect(resolvePage("/about").heading).toBe("About this application");
    expect(resolvePage("/login").status).toBe(200);
    expect(resolvePage("/dashboard").status).toBe(401);
    expect(resolvePage("/dashboard", "invalid-session").status).toBe(403);
    expect(resolvePage("/dashboard", SESSION_TOKEN).status).toBe(200);
    expect(resolvePage("/missing").status).toBe(404);
  });
});
