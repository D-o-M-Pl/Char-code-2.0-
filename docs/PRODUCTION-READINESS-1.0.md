# Char-code 2.0 — Production Readiness Audit 1.0

Audit date: 2026-08-31

## Executive result

**Status: CONDITIONAL GO for staging, NO-GO for production until external cloud/build gates pass.**

The repository is materially stronger than the original MVP and now has a coherent production security model. The application can proceed to staging. Production release should remain blocked until Docker, Prisma/PostgreSQL, Windows installer signing, Bicep deployment, and Azure runtime smoke tests are executed in real CI/Azure.

## Scorecard

| Area | Status | Score |
| --- | --- | ---: |
| Canonical repository | PASS | 9/10 |
| TypeScript build | PASS | 9/10 |
| Local E2E security tests | PASS | 8/10 |
| Authentication foundation | PASS/WARN | 7/10 |
| MFA recovery | PASS/WARN | 7/10 |
| Tenant isolation | PASS/WARN | 8/10 |
| PostgreSQL RLS design | PASS/WARN | 8/10 |
| Docker architecture | PASS/WARN | 8/10 |
| Windows compatibility model | PASS | 9/10 |
| CI / supply chain | PASS/WARN | 9/10 |
| Artifact signing | PASS/WARN | 9/10 |
| Azure deployment gate | PASS/WARN | 9/10 |
| Azure infrastructure | WARN | 7/10 |
| Observability | WARN | 6/10 |
| Backup / DR | WARN | 6/10 |
| GDPR operational readiness | WARN | 6/10 |
| Production readiness | CONDITIONAL | 7.5/10 |

## PASS

- One canonical `Char-code 2.0` structure exists.
- Separate SaaS and Windows distributions are generated from the same codebase.
- TypeScript build/typecheck previously passed.
- Local E2E covers authentication, tenant isolation, user-enumeration resistance and metrics.
- Windows x86 is correctly treated as Web/PWA-only.
- Windows x64/Windows 11 can use the Docker profile.
- PostgreSQL is not exposed publicly in the SaaS Compose design.
- Application-level tenant isolation exists.
- PostgreSQL RLS policy design exists as a second line of defense.
- DCO, CLA, Apache 2.0, NOTICE, COPYRIGHT and source headers exist.
- CODEOWNERS, SECURITY policy and branch protection guidance exist.
- Dependabot, CodeQL, secret scanning, SBOM and release attestations exist.
- Containers are signed keylessly with Cosign.
- Windows release artifacts have Sigstore bundles and Azure Artifact Signing workflow.
- SHA-256 manifests, GitHub attestations and SLSA provenance are part of release verification.
- Production deployment now consumes immutable verified container digests.
- Deployment uses GitHub OIDC rather than a long-lived Azure client secret.

## WARN — must be validated in real CI/Azure

### Prisma/PostgreSQL

The Prisma CLI and a PostgreSQL server must execute:

```text
prisma validate
prisma migrate deploy
RLS integration test
rollback/forward migration rehearsal
```

Static schema inspection is not equivalent to a real migration test.

### Docker

The environment used for this audit did not provide a Docker daemon. CI must run:

```text
docker compose config
docker compose build
docker compose up
health/readiness tests
```

### Azure Bicep

The Bicep file now includes Front Door endpoint/origin/route/WAF association and private DNS/private endpoints, but it still requires:

- `az bicep build`;
- `az deployment group what-if`;
- staging deployment;
- validation of resource API versions in the target subscription/region;
- App Service origin access restrictions;
- managed identity RBAC assignments;
- final Key Vault secret population;
- production DNS/custom domain certificate configuration.

### Windows installers

WiX/Inno builds and Azure Artifact Signing must run on the Windows GitHub runner. Validate:

- MSI install;
- EXE install;
- uninstall;
- upgrade;
- Authenticode chain;
- timestamp;
- SmartScreen/reputation behavior.

## FAIL / release blockers if not completed

Production deployment must not proceed if any of these fail:

1. `Production Release Gate`.
2. Container Cosign verification.
3. SHA-256 verification.
4. SLSA provenance verification.
5. GitHub Artifact Attestation verification.
6. Windows Authenticode verification for a Windows release.
7. PostgreSQL migrations against staging.
8. RLS cross-tenant integration tests against real PostgreSQL.
9. Docker health tests.
10. Azure post-deployment smoke test.

## Security findings

### P0-01 — Local development password hashing

The memory/local test implementation may use a simplified password adapter. Production identity must use Argon2id or a managed identity provider and must never reuse a test hashing implementation.

Status: **production adapter required**.

### P0-02 — Secrets

`.env.example` may contain placeholders only. Real secrets belong in Key Vault. Repository and workflow scanning must remain enabled.

Status: **architecturally correct; Azure RBAC must be deployed**.

### P0-03 — Tenant isolation

Tenant isolation must be tested twice:

1. HTTP authorization test.
2. Direct real-PostgreSQL RLS test.

Status: **HTTP test exists; database integration gate still required**.

### P0-04 — Deployment immutability

The production deployment workflow now consumes image references pinned by SHA-256 digest from the verification manifest.

Status: **PASS by design; validate against GHCR + Azure staging**.

## Operational readiness gaps

Before 1.0 GA:

- configure Azure Monitor/Application Insights;
- configure alerts for 5xx, latency, dead letters, DB capacity and failed logins;
- perform a restore drill;
- document on-call ownership;
- document security incident contacts;
- define retention periods for logs/audit/GDPR requests;
- define release rollback using the previous verified image digest;
- set production environment required reviewers and prevent self-review.

## Final recommendation

### Staging

**GO**, after CI validates Docker and Prisma.

### Production 1.0

**NO-GO until all external gates are green.**

The project is ready for a production rehearsal, not yet for an unqualified public production launch.
