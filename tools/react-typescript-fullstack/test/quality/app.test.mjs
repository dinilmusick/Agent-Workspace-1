import { describe, expect, it } from "vitest";
import { authorize, normalizePath, resolvePage, validateCredentials } from "../../../../examples/quality-sample/app.mjs";

describe("quality sample application", () => {
  it("normalizes local paths, queries and trailing slashes", () => {
    expect(normalizePath("/")).toBe("/");
    expect(normalizePath("/about/?tab=security")).toBe("/about");
    expect(normalizePath(undefined)).toBe("/");
  });

  it("accepts only the configured test credentials", () => {
    expect(validateCredentials({ email: "qa@example.com", password: "test" }, "qa@example.com", "test")).toBe(true);
    expect(validateCredentials({ email: "wrong@example.com", password: "test" }, "qa@example.com", "test")).toBe(false);
    expect(validateCredentials({ email: "qa@example.com", password: "wrong" }, "qa@example.com", "test")).toBe(false);
    expect(validateCredentials(null, "qa@example.com", "test")).toBe(false);
    expect(validateCredentials([], "qa@example.com", "test")).toBe(false);
  });

  it("distinguishes anonymous, forbidden and authenticated sessions", () => {
    expect(authorize("", "test-token").status).toBe(401);
    expect(authorize("invalid-session", "test-token").status).toBe(403);
    expect(authorize("test-token", "test-token")).toEqual({ allowed: true, status: 200 });
  });

  it("resolves public, protected and missing pages", () => {
    expect(resolvePage("/").status).toBe(200);
    expect(resolvePage("/about").heading).toBe("About this application");
    expect(resolvePage("/login").status).toBe(200);
    expect(resolvePage("/dashboard", "", "test-token").status).toBe(401);
    expect(resolvePage("/dashboard", "invalid-session", "test-token").status).toBe(403);
    expect(resolvePage("/dashboard", "test-token", "test-token").status).toBe(200);
    expect(resolvePage("/missing").status).toBe(404);
  });
});
