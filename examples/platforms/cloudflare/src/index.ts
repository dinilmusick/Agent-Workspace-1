export interface Env {
  TEST_KV: KVNamespace;
  APP_STAGE: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname !== "/health") {
      return new Response("not found", { status: 404 });
    }
    await env.TEST_KV.put("health", env.APP_STAGE);
    const stage = await env.TEST_KV.get("health");
    return new Response(stage ?? "missing", {
      headers: { "content-type": "text/plain" }
    });
  }
};
