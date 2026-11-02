import { createServer } from "node:http";

const page = path => {
  const content = path === "/about"
    ? "<h1>About this sample</h1><p>A real local application used to verify browser workflows.</p>"
    : path === "/login"
      ? '<h1>Sign in</h1><form id="login-form"><label for="email">Email</label><input id="email" name="email" type="email" autocomplete="username" required><label for="password">Password</label><input id="password" name="password" type="password" autocomplete="current-password" required><button type="submit">Sign in</button><p id="login-status" role="status" aria-live="polite"></p><a id="dashboard-link" href="/dashboard" hidden>Open dashboard</a></form>'
      : path === "/dashboard"
        ? '<h1 id="dashboard-title">Dashboard</h1><p id="dashboard-status">Your session is active.</p>'
        : "<h1>Welcome to Agent Workspace Sample</h1><p>This page is served by a running Node application.</p>";
  return \`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Agent Workspace Browser Sample</title>
<style>
:root{font-family:system-ui,sans-serif;color:#172033;background:#f7f9fc}
body{margin:0;min-height:100vh}header,main,footer{max-width:960px;margin:auto;padding:1.25rem}
header{display:flex;align-items:center;justify-content:space-between;gap:1rem}
nav{display:flex;gap:1rem}a{color:#164e9b}button{padding:.65rem 1rem;border:0;border-radius:.35rem;background:#164e9b;color:white;font:inherit}
input{display:block;width:100%;max-width:28rem;padding:.7rem;margin:.35rem 0 1rem;border:1px solid #65748b;border-radius:.3rem;font:inherit}
main{background:white;border:1px solid #d8deea;border-radius:.6rem;min-height:18rem}
:focus-visible{outline:3px solid #d97706;outline-offset:2px}
#nav-toggle{display:none}
@media(max-width:600px){header{align-items:flex-start;flex-wrap:wrap}#nav-toggle{display:inline-block}nav{display:none;width:100%;flex-direction:column}nav[data-open="true"]{display:flex}main{margin:0 .75rem}}
</style>
</head>
<body>
<header><a href="/" aria-label="Agent Workspace home">Agent Workspace</a>
<button id="nav-toggle" type="button" aria-controls="primary-nav" aria-expanded="false">Menu</button>
<nav id="primary-nav" aria-label="Main navigation" data-open="true">
<a href="/">Home</a><a href="/about">About</a><a href="/login">Sign in</a>
</nav></header>
<main>\${content}</main><footer><p>Browser harness sample application</p></footer>
<script>
const toggle=document.querySelector("#nav-toggle");
const nav=document.querySelector("#primary-nav");
toggle.addEventListener("click",()=>{const open=nav.dataset.open!=="true";nav.dataset.open=String(open);toggle.setAttribute("aria-expanded",String(open));});
if(location.pathname==="/dashboard"&&!localStorage.getItem("sample-session"))location.replace("/login");
const form=document.querySelector("#login-form");
if(form)form.addEventListener("submit",async event=>{event.preventDefault();const response=await fetch("/api/login",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({email:form.email.value,password:form.password.value})});const result=await response.json();const status=document.querySelector("#login-status");if(response.ok){localStorage.setItem("sample-session",result.token);status.textContent="Signed in";document.querySelector("#dashboard-link").hidden=false;}else status.textContent="Sign in failed";});
</script>
</body></html>\`;
};

const server = createServer(async (request, response) => {
  if (request.method === "GET" && request.url === "/health") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({ ok: true }));
    return;
  }
  if (request.method === "POST" && request.url === "/api/login") {
    let body = "";
    for await (const chunk of request) body += chunk;
    const credentials = JSON.parse(body || "{}");
    const ok = credentials.email === "qa@example.com" && credentials.password === "browser-test";
    response.writeHead(ok ? 200 : 401, { "content-type": "application/json" });
    response.end(JSON.stringify(ok ? { token: "sample-session-token" } : { error: "invalid_credentials" }));
    return;
  }
  if (request.method === "GET" && ["/", "/about", "/login", "/dashboard"].includes(request.url)) {
    response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    response.end(page(request.url));
    return;
  }
  response.writeHead(404, { "content-type": "text/plain" });
  response.end("Not found");
});

const port = Number(process.env.PORT ?? 4173);
const host = process.env.HOST ?? "127.0.0.1";
server.listen(port, host, () => process.stdout.write("Browser sample listening on http://" + host + ":" + port + "\n"));
