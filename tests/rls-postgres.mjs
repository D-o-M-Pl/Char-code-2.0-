// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

import assert from "node:assert/strict";
import { PrismaClient } from "@prisma/client";

const adminUrl = process.env.MIGRATION_DATABASE_URL ?? process.env.DATABASE_URL;

if (!adminUrl) {
  throw new Error("MIGRATION_DATABASE_URL or DATABASE_URL is required.");
}

const runtimePassword =
  process.env.RLS_TEST_PASSWORD ?? "Rls-Test-Only-2026!ChangeMe";
const runtimeRole = "char_code_rls_test";
const tenantA = "00000000-0000-0000-0000-00000000000a";
const tenantB = "00000000-0000-0000-0000-00000000000b";
const userA = "10000000-0000-0000-0000-00000000000a";

function runtimeUrlFromAdminUrl(urlString) {
  const url = new URL(urlString);
  url.username = runtimeRole;
  url.password = runtimePassword;
  return url.toString();
}

const admin = new PrismaClient({
  datasources: { db: { url: adminUrl } },
});

const runtimeUrl = runtimeUrlFromAdminUrl(adminUrl);
let runtime;

async function setTenant(tx, tenantId, isPlatformAdmin = false) {
  await tx.$executeRaw`
    SELECT set_config('app.tenant_id', ${tenantId}, true)
  `;
  await tx.$executeRaw`
    SELECT set_config(
      'app.is_platform_admin',
      ${String(isPlatformAdmin)},
      true
    )
  `;
}

async function resetFixtures() {
  await admin.task.deleteMany({
    where: { id: { in: ["rls-task-a", "rls-task-b"] } },
  });
  await admin.organizationMembership.deleteMany({
    where: {
      organizationId: { in: [tenantA, tenantB] },
      userId: userA,
    },
  });
  await admin.user.deleteMany({ where: { id: userA } });
  await admin.organization.deleteMany({
    where: { id: { in: [tenantA, tenantB] } },
  });
}

try {
  await admin.$executeRawUnsafe(`DROP ROLE IF EXISTS ${runtimeRole}`);
  await admin.$executeRawUnsafe(
    `CREATE ROLE ${runtimeRole} LOGIN PASSWORD '${runtimePassword.replaceAll("'", "''")}' NOBYPASSRLS IN ROLE char_code_app`,
  );

  await resetFixtures();

  await admin.organization.createMany({
    data: [
      { id: tenantA, name: "RLS NGO A" },
      { id: tenantB, name: "RLS NGO B" },
    ],
  });

  await admin.user.create({
    data: {
      id: userA,
      email: "rls-admin-a@example.test",
      displayName: "RLS Admin A",
      passwordHash: "not-used-by-rls-test",
      role: "ORGANIZATION_ADMIN",
    },
  });

  await admin.organizationMembership.create({
    data: {
      organizationId: tenantA,
      userId: userA,
      role: "ORGANIZATION_ADMIN",
    },
  });

  await admin.task.createMany({
    data: [
      {
        id: "rls-task-a",
        organizationId: tenantA,
        title: "Tenant A secret",
        status: "OPEN",
      },
      {
        id: "rls-task-b",
        organizationId: tenantB,
        title: "Tenant B secret",
        status: "OPEN",
      },
    ],
  });

  runtime = new PrismaClient({
    datasources: { db: { url: runtimeUrl } },
  });
  await runtime.$connect();

  const noContext = await runtime.task.findMany({
    where: { id: { in: ["rls-task-a", "rls-task-b"] } },
  });
  assert.equal(
    noContext.length,
    0,
    "RLS must default-deny when tenant context is absent.",
  );

  const noContextMemberships = await runtime.organizationMembership.findMany({
    where: { userId: userA },
  });
  assert.equal(
    noContextMemberships.length,
    0,
    "Membership RLS must default-deny without tenant context.",
  );

  const tenantAMemberships = await runtime.$transaction(async (tx) => {
    await setTenant(tx, tenantA);
    return tx.organizationMembership.findMany({
      where: { userId: userA },
    });
  });
  assert.equal(
    tenantAMemberships.length,
    1,
    "Membership must be visible only after tenant context is set.",
  );

  const tenantARows = await runtime.$transaction(async (tx) => {
    await setTenant(tx, tenantA);

    // Deliberately no organizationId filter: PostgreSQL must enforce RLS.
    return tx.task.findMany({
      where: { id: { in: ["rls-task-a", "rls-task-b"] } },
      orderBy: { id: "asc" },
    });
  });

  assert.deepEqual(
    tenantARows.map((row) => row.id),
    ["rls-task-a"],
    "Tenant A must never observe Tenant B rows.",
  );

  const tenantBRows = await runtime.$transaction(async (tx) => {
    await setTenant(tx, tenantB);
    return tx.task.findMany({
      where: { id: { in: ["rls-task-a", "rls-task-b"] } },
      orderBy: { id: "asc" },
    });
  });

  assert.deepEqual(
    tenantBRows.map((row) => row.id),
    ["rls-task-b"],
    "Tenant B must never observe Tenant A rows.",
  );

  const crossTenantUpdate = await runtime.$transaction(async (tx) => {
    await setTenant(tx, tenantA);
    return tx.task.updateMany({
      where: { id: "rls-task-b" },
      data: { title: "COMPROMISED" },
    });
  });

  assert.equal(
    crossTenantUpdate.count,
    0,
    "RLS must block cross-tenant UPDATE.",
  );

  const tenantBTask = await admin.task.findUnique({
    where: { id: "rls-task-b" },
  });
  assert.equal(
    tenantBTask?.title,
    "Tenant B secret",
    "Foreign tenant data must remain unchanged.",
  );

  const roleFlags = await admin.$queryRawUnsafe(
    `SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = '${runtimeRole}'`,
  );

  assert.equal(roleFlags.length, 1);
  assert.equal(roleFlags[0].rolsuper, false);
  assert.equal(roleFlags[0].rolbypassrls, false);

  const forceFlags = await admin.$queryRaw`
    SELECT relname, relforcerowsecurity
    FROM pg_class
    WHERE relname IN ('tasks', 'organization_memberships')
    ORDER BY relname
  `;

  assert.equal(forceFlags.length, 2);
  assert.ok(
    forceFlags.every((row) => row.relforcerowsecurity === true),
    "Tenant tables must FORCE ROW LEVEL SECURITY.",
  );

  console.log(
    "RLS PASS: default-deny, tenant A/B isolation, cross-tenant UPDATE denial, NOBYPASSRLS, FORCE RLS",
  );
} finally {
  if (runtime) await runtime.$disconnect();
  await resetFixtures().catch(() => undefined);
  await admin.$executeRawUnsafe(`DROP ROLE IF EXISTS ${runtimeRole}`).catch(() => undefined);
  await admin.$disconnect();
}