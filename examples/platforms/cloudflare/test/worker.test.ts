import { env, exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

describe("local Cloudflare Worker runtime", () => {
  it("provides a real KV binding", async () => {
    await env.TEST_KV.put("adapter", "miniflare");
    expect(await env.TEST_KV.get("adapter")).toBe("miniflare");
  });

  it("dispatches the Worker fetch handler with configured bindings", async () => {
    const response = await exports.default.fetch(new Request("https://fixture.local/health"));
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("test");
  });
});
