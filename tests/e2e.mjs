import assert from "node:assert/strict";
import { spawn } from "node:child_process";

const child = spawn(process.execPath, ["apps/api/dist/index.js"], {
  env: { ...process.env, PORT: "3217", HOST: "127.0.0.1", DATABASE_MODE: "memory" },
  stdio: ["ignore", "pipe", "pipe"]
});

const base = "http://127.0.0.1:3217";
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function waitReady() {
  for (let i = 0; i < 30; i++) {
    try {
      const response = await fetch(`${base}/health/live`);
      if (response.ok) return;
    } catch {}
    await sleep(100);
  }
  throw new Error("API did not start.");
}

try {
  await waitReady();

  const loginResponse = await fetch(`${base}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      email: "admin-a@example.test",
      password: "Correct-Horse-2026!"
    })
  });
  assert.equal(loginResponse.status, 200);
  const { accessToken } = await loginResponse.json();

  const own = await fetch(`${base}/api/tenant/tasks`, {
    headers: {
      authorization: `Bearer ${accessToken}`,
      "x-organization-id": "00000000-0000-0000-0000-00000000000a"
    }
  });
  assert.equal(own.status, 200);
  const ownBody = await own.json();
  assert.equal(ownBody.tasks.length, 1);
  assert.equal(ownBody.tasks[0].organizationId, "00000000-0000-0000-0000-00000000000a");

  const crossTenant = await fetch(`${base}/api/tenant/tasks`, {
    headers: {
      authorization: `Bearer ${accessToken}`,
      "x-organization-id": "00000000-0000-0000-0000-00000000000b"
    }
  });
  assert.equal(crossTenant.status, 403);

  const existing = await fetch(`${base}/api/account/password/forgot`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "admin-a@example.test" })
  });
  const missing = await fetch(`${base}/api/account/password/forgot`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "missing@example.test" })
  });
  assert.equal(existing.status, missing.status);
  assert.deepEqual(await existing.json(), await missing.json());

  const metrics = await fetch(`${base}/metrics`);
  assert.equal(metrics.status, 200);
  assert.match(await metrics.text(), /char_code_outbox_pending/);

  console.log("E2E PASS: auth, tenant isolation, enumeration resistance, metrics");
} finally {
  child.kill("SIGTERM");
}
