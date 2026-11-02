import { randomUUID } from "node:crypto";
import { createServer } from "node:http";
import { authorize, resolvePage, SESSION_TOKEN, validateCredentials } from "./app.mjs";

async function readJson(request) {
  let body = "";
  for await (const chunk of request) body += chunk;
  return body ? JSON.parse(body) : {};
}

function send(response, status, body, contentType = "application/json; charset=utf-8") {
  response.writeHead(status, { "content-type": contentType, "cache-control": "no-store" });
  response.end(contentType.startsWith("application/json") ? JSON.stringify(body) : body);
}

function renderPage(page) {
  return [
    "<!doctype html>",
    '<html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<meta name="description" content="A secure sample application for automated quality gate validation.">',
    "<title>" + page.title + "</title>",
    "<style>body{font-family:system-ui,sans-serif;max-width:52rem;margin:3rem auto;padding:0 1rem;color:#172033}nav{display:flex;gap:1rem;margin-bottom:2rem}a{color:#164e9b}main{border:1px solid #d8deea;border-radius:.5rem;padding:1.5rem}h1{line-height:1.2}footer{margin-top:2rem;color:#526078}</style>",
    "</head><body><header><a href=\"/\">Quality Sample</a>",
    '<nav aria-label="Main navigation"><a href="/">Home</a><a href="/about">About</a><a href="/login">Sign in</a></nav></header>',
    "<main><h1>" + page.heading + "</h1><p>" + page.body + "</p></main>",
    "<footer><p>Local quality gate sample</p></footer></body></html>"
  ].join("");
}

const server = createServer(async (request, response) => {
  const started = Date.now();
  const url = new URL(request.url ?? "/", "http://localhost");
  const correlationId = request.headers["x-correlation-id"] ?? randomUUID();
  const authorization = request.headers.authorization ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  response.setHeader("x-correlation-id", correlationId);
  let status = 500;

  try {
    if (request.method === "GET" && url.pathname === "/health") {
      status = 200;
      send(response, status, { status: "ok" });
    } else if (request.method === "POST" && url.pathname === "/api/login") {
      const credentials = await readJson(request);
      if (!validateCredentials(credentials)) {
        status = 401;
        send(response, status, { error: "invalid_credentials" });
      } else {
        status = 200;
        send(response, status, { token: SESSION_TOKEN });
      }
    } else if (request.method === "GET" && url.pathname === "/api/private") {
      const access = authorize(token);
      status = access.status;
      send(response, status, access.allowed ? { data: "private" } : { error: access.status === 401 ? "unauthenticated" : "forbidden" });
    } else if (request.method === "GET") {
      const page = resolvePage(url.pathname, token);
      status = page.status;
      send(response, status, renderPage(page), "text/html; charset=utf-8");
    } else {
      status = 404;
      send(response, status, { error: "not_found" });
    }
  } catch {
    status = 400;
    if (!response.headersSent) send(response, status, { error: "invalid_request" });
  } finally {
    process.stdout.write(JSON.stringify({
      timestamp: new Date().toISOString(),
      level: status >= 500 ? "error" : status >= 400 ? "warn" : "info",
      correlationId,
      method: request.method,
      path: url.pathname,
      status,
      durationMs: Date.now() - started
    }) + "\n");
  }
});

const port = Number(process.env.PORT ?? 4173);
const host = process.env.HOST ?? "127.0.0.1";
server.listen(port, host, () => process.stdout.write("Quality sample listening on http://" + host + ":" + port + "\n"));
