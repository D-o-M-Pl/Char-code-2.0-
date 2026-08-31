import assert from "node:assert/strict";

const baseUrl = (process.env.SMOKE_BASE_URL ?? "").replace(/\/+$/, "");
const email = process.env.SMOKE_EMAIL ?? "admin-a@example.test";
const password = process.env.SMOKE_PASSWORD ?? "Correct-Horse-2026!";
const ownTenant =
  process.env.SMOKE_OWN_TENANT ?? "00000000-0000-0000-0000-00000000000a";
const foreignTenant =
  process.env.SMOKE_FOREIGN_TENANT ?? "00000000-0000-0000-0000-00000000000b";

if (!baseUrl) {
  throw new Error("SMOKE_BASE_URL is required.");
}

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    redirect: "error",
    ...options,
  });

  return response;
}

async function waitForHealthy() {
  let lastError = "unknown";

  for (let attempt = 1; attempt <= 30; attempt += 1) {
    try {
      const response = await request("/backend/health/live");
      if (response.ok) return;
      lastError = `HTTP ${response.status}`;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }

    await new Promise((resolve) => setTimeout(resolve, 10_000));
  }

  throw new Error(`Health check never became ready: ${lastError}`);
}

await waitForHealthy();

const ready = await request("/backend/health/ready");
assert.equal(ready.status, 200, "Readiness endpoint must return HTTP 200.");

const login = await request("/backend/api/auth/login", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ email, password }),
});
assert.equal(login.status, 200, "Smoke user login must succeed.");

const loginBody = await login.json();
assert.equal(typeof loginBody.accessToken, "string");
assert.ok(loginBody.accessToken.length >= 20);

const own = await request("/backend/api/tenant/tasks", {
  headers: {
    authorization: `Bearer ${loginBody.accessToken}`,
    "x-organization-id": ownTenant,
  },
});
assert.equal(own.status, 200, "Own tenant access must succeed.");

const foreign = await request("/backend/api/tenant/tasks", {
  headers: {
    authorization: `Bearer ${loginBody.accessToken}`,
    "x-organization-id": foreignTenant,
  },
});
assert.equal(foreign.status, 403, "Cross-tenant access must be denied.");

const securityHeaders = await request("/");
assert.equal(
  securityHeaders.headers.get("x-content-type-options"),
  "nosniff",
  "Web security headers must be present.",
);

console.log(
  JSON.stringify(
    {
      status: "PASS",
      baseUrl,
      checks: [
        "liveness",
        "readiness",
        "login",
        "own-tenant-access",
        "cross-tenant-denied",
        "security-headers",
      ],
    },
    null,
    2,
  ),
);
