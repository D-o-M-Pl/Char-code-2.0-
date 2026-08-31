# Char-code 2.0 — Architect Security, Correctness & Integrity Audit

Audit date: 2026-08-31

## Decision

**Code/static gate: PASS**

**Production v2.0.0: CONDITIONAL NO-GO until the external execution gates below are green.**

## Executed successfully in this environment

- TypeScript strict typecheck.
- TypeScript build.
- Memory-adapter E2E.
- E2E auth/login.
- E2E application tenant isolation.
- User-enumeration resistance.
- Metrics endpoint.
- JavaScript syntax validation for real PostgreSQL RLS test.
- JavaScript syntax validation for Azure smoke test.
- GitHub Actions YAML parsing.
- Docker Compose YAML parsing.
- Dockerfile structural integrity checks.
- RLS structural/invariant checks.
- RC promotion workflow invariants.
- Secret heuristic scan.
- Bicep structural/security checks.

## Security corrections made during audit

### Prisma is production default

`MemoryStore` is now accepted only when explicitly requested.

`NODE_ENV=production` + `DATABASE_MODE=memory` fails closed.

### Real RLS boundary

Tenant-owned data uses:

```text
ENABLE ROW LEVEL SECURITY
FORCE ROW LEVEL SECURITY
```

A separate `char_code_app` database role is:

```text
NOLOGIN
NOBYPASSRLS
```

Production runtime credentials must be a non-superuser login member of `char_code_app`.

### Migration/runtime identity separation

```text
MIGRATION_DATABASE_URL -> owner/admin migration identity
DATABASE_URL           -> least-privilege runtime identity
```

They must never resolve to the same privileged login in production.

### Membership check fixed

`organization_memberships` is itself RLS-protected.

Membership lookup and tenant data access now execute inside the same transaction after transaction-local tenant context is established.

### RLS test intentionally bypasses application filtering

The PostgreSQL RLS test deliberately queries two tenants without an `organizationId` application filter.

Expected result:

```text
no tenant context -> 0 rows
tenant A context  -> only tenant A
tenant B context  -> only tenant B
tenant A UPDATE B -> 0 rows affected
```

This proves the database boundary rather than the controller filter.

### Password hashing strengthened

The built-in scrypt profile is now:

```text
N = 2^17
r = 8
p = 1
```

with per-password random salt and timing-safe comparison.

### Error disclosure fixed

Unhandled server exceptions are logged server-side and clients receive only:

```json
{"error":"INTERNAL_ERROR"}
```

### Docker Prisma runtime fixed

The API container now:

- installs dependencies;
- generates Prisma Client;
- compiles TypeScript;
- prunes development dependencies;
- copies generated Prisma runtime dependencies into the final image;
- defaults to `NODE_ENV=production`, `DATABASE_MODE=prisma`, `HOST=0.0.0.0`.

### Web/API runtime routing fixed

Nginx uses runtime:

```text
API_UPSTREAM
```

rather than a Compose-only fixed hostname.

### Slot integrity fixed

Environment-dependent settings are deployment-slot settings and do not swap accidentally.

In particular:

- staging Web -> staging API;
- production Web -> production API;
- staging DB URL -> staging DB;
- production DB URL -> production DB.

### RC promotion integrity

Promotion flow is:

```text
v2.0.0-rc.N
→ verify signed immutable images
→ staging slots
→ smoke
→ protected production approval
→ slot swap
→ production smoke
→ deployed digest comparison
→ reverse swap on failure
```

### Front Door bypass protection

The production Web origin is restricted to:

```text
AzureFrontDoor.Backend
+
X-Azure-FDID == exact Front Door profile
```

with unmatched traffic denied.

## Real PostgreSQL RLS workflow

File:

```text
.github/workflows/postgres-rls.yml
```

It starts PostgreSQL 16 and runs:

```text
Prisma generate
Prisma validate
migrate deploy
real RLS tests
```

This workflow is mandatory before production merge/release.

## External execution gates not runnable in this environment

### PostgreSQL

**NOT EXECUTED HERE**

No PostgreSQL server or Docker daemon is installed in the artifact environment.

Must pass in GitHub Actions:

```text
PostgreSQL RLS / Real PostgreSQL RLS
```

### Prisma CLI

**NOT EXECUTED HERE**

The provided artifact environment does not contain registry-installed Prisma CLI binaries.

CI must run dependency installation first, then:

```text
npm run prisma:generate
npm run prisma:validate
npm run db:migrate
```

### Docker

**NOT EXECUTED HERE**

No Docker daemon is available.

Required:

```text
docker compose config
docker compose build
docker compose up
smoke tests
```

### Azure/Bicep

**NOT EXECUTED HERE**

No Azure subscription or Bicep compiler is attached.

Required:

```text
az bicep build
az deployment group what-if
staging deployment
slot swap rehearsal
reverse swap rehearsal
Front Door/WAF smoke
```

## Remaining production blockers

### BLOCKER — npm lockfile

The offline artifact does not include a registry-generated `package-lock.json`.

Top-level dependencies are exact-pinned, but `v2.0.0` is NO-GO until a trusted connected environment generates, reviews and commits the lockfile.

After that, CI should use `npm ci`.

### BLOCKER — real PostgreSQL RLS execution

Static and syntax validation passed, but the real PostgreSQL 16 workflow must be green.

### BLOCKER — Docker build execution

Both API and Web images must successfully build and run in CI.

### BLOCKER — Bicep compile/what-if/deploy

Static security inspection is not equivalent to Azure deployment validation.

### BLOCKER — production database identities

Create and verify separate migration and runtime identities. Runtime must be `NOSUPERUSER NOBYPASSRLS`.

### BLOCKER — API ingress restriction

Front Door protects Web ingress, but the API App Service must also be restricted so it is not a generic public origin.

Recommended options:

1. VNet/private endpoint path from Web to API; or
2. strict App Service access restrictions permitting only the intended Web/BFF network path.

Validate this in the target Azure topology.

### WARN — GitHub Actions immutable pins

Actions currently use version tags such as `@v5`, `@v3`.

For maximum supply-chain hardening, replace action tags with reviewed immutable commit SHAs and let Dependabot maintain them.

### WARN — Outbox concurrency

Before horizontally scaling workers, implement an atomic claim/lease pattern such as `FOR UPDATE SKIP LOCKED` or a claim status with lease expiry to prevent duplicate event processing.

### WARN — reset-token material in outbox

The raw password-reset token is temporarily included in an outbox payload so the notification worker can deliver it.

Before production handling of sensitive accounts, encrypt sensitive outbox payloads using a Key Vault-managed/envelope-encryption design or redesign delivery so plaintext reset capability is minimized.

## Integrity result

No obvious embedded GitHub tokens, AWS access keys or private keys were detected by the local heuristic scan.

Repository secret scanning/Gitleaks remains mandatory because a heuristic local scan is not a substitute for full history scanning.

## Final recommendation

### Merge to staging branch

**GO**, after normal code review.

### Create `v2.0.0-rc.1`

**GO**, once the lockfile is committed and CI can install dependencies.

### Promote RC to production

**NO-GO** until all external blockers are green.

### `v2.0.0` GA

Release only after:

- real PostgreSQL RLS PASS;
- Docker build/runtime PASS;
- Bicep compile + what-if PASS;
- staging smoke PASS;
- rollback rehearsal PASS;
- production approval;
- production smoke PASS;
- deployed image digests equal approved signed digests.
