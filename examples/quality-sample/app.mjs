export const SESSION_TOKEN = "quality-sample-session";
const VALID_EMAIL = "qa@example.com";
const VALID_PASSWORD = "quality-test";

export function normalizePath(value) {
  const input = typeof value === "string" ? value : "/";
  const pathname = new URL(input, "http://localhost").pathname;
  return pathname.replace(/\/+$/, "") || "/";
}

export function validateCredentials(credentials) {
  if (!credentials || typeof credentials !== "object" || Array.isArray(credentials)) return false;
  return credentials.email === VALID_EMAIL && credentials.password === VALID_PASSWORD;
}

export function authorize(token) {
  if (typeof token !== "string" || token.length === 0) return { allowed: false, status: 401 };
  if (token !== SESSION_TOKEN) return { allowed: false, status: 403 };
  return { allowed: true, status: 200 };
}

export function resolvePage(path, token) {
  switch (normalizePath(path)) {
    case "/":
      return { status: 200, title: "Quality Sample", heading: "Quality Gate Sample", body: "A real local application for security, API, coverage and Lighthouse validation." };
    case "/about":
      return { status: 200, title: "About | Quality Sample", heading: "About this application", body: "This page is served by a running Node application." };
    case "/login":
      return { status: 200, title: "Sign in | Quality Sample", heading: "Sign in", body: "Use the test account to obtain a session." };
    case "/dashboard": {
      const access = authorize(token);
      if (!access.allowed) return { status: access.status, title: "Access denied | Quality Sample", heading: "Access denied", body: "A valid session is required." };
      return { status: 200, title: "Dashboard | Quality Sample", heading: "Private dashboard", body: "Authenticated content is available." };
    }
    default:
      return { status: 404, title: "Not found | Quality Sample", heading: "Page not found", body: "The requested page does not exist." };
  }
}
