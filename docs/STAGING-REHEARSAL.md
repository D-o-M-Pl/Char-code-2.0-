# Staging Deployment and Rollback Rehearsal

## Goal

Prove that the exact signed release images can be deployed to Azure staging, pass security smoke tests, and be rolled back to the previous staging baseline.

## GitHub environment

Create `staging`.

Repository/environment variables:

```text
AZURE_STAGING_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_API_APP_NAME
AZURE_WEB_APP_NAME
STAGING_SMOKE_OWN_TENANT
STAGING_SMOKE_FOREIGN_TENANT
```

Secrets:

```text
GHCR_PULL_USERNAME
GHCR_PULL_TOKEN
STAGING_SMOKE_EMAIL
STAGING_SMOKE_PASSWORD
```

Use a read-only package token for GHCR pulls.

## Run

Create a signed release candidate such as:

```text
v2.0.0-rc.1
```

Run:

```text
Actions
→ Azure Staging Rehearsal
→ tag: v2.0.0-rc.1
→ exercise_rollback: true
```

The workflow:

```text
verify signed container digests
        ↓
ensure staging slots exist
        ↓
capture previous staging images
        ↓
deploy candidate images by digest
        ↓
smoke test
        ↓
PASS ───────────────┐
                    │
exercise rollback?  │
       ↓ yes        │ no
restore baseline    │
       ↓            │
smoke baseline      │
       └────────────┴→ complete
```

Any deployment/smoke failure attempts automatic restoration of the previous staging image references.

## Smoke tests

The smoke test validates:

- liveness;
- readiness;
- login;
- access to the correct tenant;
- denial of access to a foreign tenant;
- web security headers.

## Required rehearsal sequence for v2.0.0

1. Establish a known-good staging baseline.
2. Run `v2.0.0-rc.1` with rollback exercise enabled.
3. Confirm candidate smoke passes.
4. Confirm rollback smoke passes.
5. Run the candidate again with rollback exercise disabled.
6. Perform manual exploratory test.
7. Run database migration rehearsal separately.
8. Only then create `v2.0.0`.

## Important production gap

The current API code still uses the in-memory store in its runnable path. `DATABASE_MODE=memory` is therefore deliberate for this infrastructure rehearsal.

This is **not sufficient for production v2.0.0**. Real Prisma/PostgreSQL runtime integration and RLS integration tests remain a hard GO-LIVE blocker.
