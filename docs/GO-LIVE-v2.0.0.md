# Char-code 2.0 — GO LIVE Checklist v2.0.0

Release: `v2.0.0`

Decision rule:

> Any unchecked **BLOCKER** item means **NO-GO**.

## 0. Release governance

- [ ] **BLOCKER** Release owner assigned.
- [ ] **BLOCKER** Incident commander/on-call owner assigned.
- [ ] **BLOCKER** Change window agreed.
- [ ] **BLOCKER** `main` and `release/*` rulesets active.
- [ ] **BLOCKER** DCO, CODEOWNERS, CI and security checks required.
- [ ] Release notes approved.
- [ ] Apache 2.0 `LICENSE`, `NOTICE`, `COPYRIGHT` confirmed.

## 1. Application build

- [ ] **BLOCKER** TypeScript typecheck green.
- [ ] **BLOCKER** Production build green.
- [ ] **BLOCKER** E2E green.
- [ ] **BLOCKER** Cross-tenant E2E returns 403.
- [ ] **BLOCKER** No test/demo credentials are enabled in production.
- [ ] **BLOCKER** Production password hashing uses Argon2id or managed identity provider.
- [ ] No high/critical unresolved production dependency vulnerability.

## 2. PostgreSQL / Prisma

- [ ] **BLOCKER** Runnable API uses real Prisma/PostgreSQL in production.
- [ ] **BLOCKER** `prisma validate` passes.
- [ ] **BLOCKER** Clean-database migrations pass.
- [ ] **BLOCKER** Upgrade migrations pass on staging copy of production-like data.
- [ ] **BLOCKER** PostgreSQL RLS integration tests pass against a real database.
- [ ] **BLOCKER** Tenant A cannot query Tenant B even when application filtering is intentionally bypassed in the DB test.
- [ ] Migration locking/concurrency behavior tested.
- [ ] Required indexes reviewed.
- [ ] Connection limits/pooling reviewed.

## 3. Authentication / authorization

- [ ] **BLOCKER** Login/logout/session revocation tested.
- [ ] **BLOCKER** Password reset tested.
- [ ] **BLOCKER** MFA setup/recovery tested.
- [ ] **BLOCKER** Recovery codes are one-time.
- [ ] **BLOCKER** RBAC tests cover admin/support/volunteer roles.
- [ ] **BLOCKER** Entra/OIDC state, nonce, PKCE, issuer, audience and JWKS validation tested if SSO is enabled.
- [ ] Brute-force/rate limiting tested.

## 4. Secrets

- [ ] **BLOCKER** Secret scan green.
- [ ] **BLOCKER** No production secrets in GitHub repository/history.
- [ ] **BLOCKER** Azure secrets stored in Key Vault.
- [ ] **BLOCKER** Managed Identity/OIDC used where supported.
- [ ] GHCR pull token is read-only and scoped minimally, or deployment has migrated to ACR + Managed Identity.
- [ ] Credential rotation procedure documented.

## 5. Containers / supply chain

- [ ] **BLOCKER** API image built successfully.
- [ ] **BLOCKER** Web image built successfully.
- [ ] **BLOCKER** Images pushed by immutable digest.
- [ ] **BLOCKER** Cosign verification green.
- [ ] **BLOCKER** CodeQL green.
- [ ] **BLOCKER** Gitleaks green.
- [ ] **BLOCKER** CycloneDX/SPDX SBOM generated.
- [ ] **BLOCKER** SLSA provenance verifies.
- [ ] **BLOCKER** GitHub artifact attestations verify.
- [ ] Base images reviewed for high/critical CVEs.

## 6. Windows release

- [ ] **BLOCKER** MSI builds on Windows runner.
- [ ] **BLOCKER** EXE builds on Windows runner.
- [ ] **BLOCKER** Authenticode signature is `Valid`.
- [ ] **BLOCKER** RFC3161 timestamp present.
- [ ] **BLOCKER** SHA-256 manifests verify.
- [ ] **BLOCKER** Sigstore bundles verify.
- [ ] Install tested on supported Windows 10 x64 environment.
- [ ] Install tested on Windows 11 x64.
- [ ] Web fallback tested on Windows 10 x86.
- [ ] Uninstall tested.
- [ ] Upgrade from previous installer tested.

## 7. Azure infrastructure

- [ ] **BLOCKER** `az bicep build` passes.
- [ ] **BLOCKER** `az deployment group what-if` reviewed.
- [ ] **BLOCKER** Staging deployment succeeds.
- [ ] **BLOCKER** PostgreSQL has no public network access.
- [ ] **BLOCKER** Key Vault private access/RBAC validated.
- [ ] **BLOCKER** Front Door route reaches Web origin.
- [ ] **BLOCKER** WAF is attached to the active Front Door route/security policy.
- [ ] **BLOCKER** Origin bypass is restricted.
- [ ] Custom domain resolves correctly.
- [ ] TLS certificate valid.
- [ ] TLS/security headers reviewed.

## 8. Staging rehearsal

- [ ] **BLOCKER** Signed `v2.0.0-rc.*` images verified with Cosign.
- [ ] **BLOCKER** Candidate deployed to staging by digest.
- [ ] **BLOCKER** Liveness passes.
- [ ] **BLOCKER** Readiness passes.
- [ ] **BLOCKER** Login smoke passes.
- [ ] **BLOCKER** Own-tenant access passes.
- [ ] **BLOCKER** Cross-tenant access is denied.
- [ ] **BLOCKER** Automatic rollback path tested.
- [ ] **BLOCKER** Baseline works after rollback.
- [ ] Manual exploratory testing complete.

## 9. Observability

- [ ] **BLOCKER** Application Insights/Azure Monitor receives telemetry.
- [ ] **BLOCKER** 5xx alert configured.
- [ ] **BLOCKER** availability alert configured.
- [ ] **BLOCKER** DB capacity/connection alert configured.
- [ ] Dead-letter/outbox alert configured.
- [ ] Authentication anomaly alert configured.
- [ ] Correlation IDs visible end-to-end.
- [ ] Dashboard available to on-call owner.

## 10. Backup / disaster recovery

- [ ] **BLOCKER** PostgreSQL backup/PITR enabled.
- [ ] **BLOCKER** Restore rehearsal completed successfully.
- [ ] **BLOCKER** Achieved RPO recorded.
- [ ] **BLOCKER** Achieved RTO recorded.
- [ ] Previous verified container digests recorded.
- [ ] Production rollback procedure rehearsed.

## 11. GDPR / privacy

- [ ] **BLOCKER** Privacy notice approved.
- [ ] **BLOCKER** Data retention rules defined.
- [ ] **BLOCKER** Export workflow tested.
- [ ] **BLOCKER** Deletion/anonymization workflow tested.
- [ ] Processor/subprocessor inventory reviewed.
- [ ] Audit retention defined.
- [ ] Production logging verified not to capture passwords/MFA secrets/tokens.

## 12. Production release gate

- [ ] **BLOCKER** `SHA256SUMS.txt` verifies.
- [ ] **BLOCKER** Authenticode verifies.
- [ ] **BLOCKER** Sigstore verifies.
- [ ] **BLOCKER** GitHub Artifact Attestations verify.
- [ ] **BLOCKER** SLSA provenance verifies.
- [ ] **BLOCKER** Signed API/Web image digests verify.
- [ ] **BLOCKER** `Production Artifact Gate` green.
- [ ] **BLOCKER** Production environment reviewer approves.

## 13. Deployment

- [ ] **BLOCKER** Deploy workflow uses the exact verified digests.
- [ ] **BLOCKER** No rebuild occurs after artifact verification.
- [ ] **BLOCKER** Production smoke test passes through Front Door.
- [ ] **BLOCKER** API/Web deployed digest matches verification manifest.
- [ ] Error rate stable for initial observation window.
- [ ] Latency stable for initial observation window.

## 14. Rollback trigger

Immediately roll back when any of these occur:

- production health/readiness fails;
- sustained 5xx spike;
- authentication failure regression;
- cross-tenant authorization anomaly;
- migration/data integrity issue;
- WAF/origin routing failure;
- critical security alert;
- deployed digest differs from approved digest.

## Final decision

### GO

Sign only when every BLOCKER above is checked:

```text
Release: v2.0.0
Decision: GO
Release owner:
Security reviewer:
Operations reviewer:
Timestamp:
Approved API digest:
Approved Web digest:
Database migration version:
```

### NO-GO

Any unchecked BLOCKER:

```text
Decision: NO-GO
Reason:
Owner:
Remediation:
Next review:
```

## Current repository status

At the time this checklist was generated, the repository is **not yet eligible for GO** because real Prisma/PostgreSQL runtime integration and real cloud/installer execution have not been demonstrated in this environment.
