# Commit Plan — All Repositories

All commits should use DCO:

```bash
git commit -s
```

Never force-push protected branches or version tags.

## Char-code

Canonical integrated product.

Recommended sequence:

```text
build: establish Char-code 2.0 canonical repository
security(db): enforce RLS and least-privilege runtime identity
security(network): make Azure API private-only
feat(worker): add atomic leased outbox processing
test(security): add real PostgreSQL RLS and outbox concurrency gates
ci(security): add DCO CodeQL secret scan SBOM and provenance
ci(release): add signed RC staging approval and production promotion
infra(azure): add Front Door WAF private endpoints and deployment slots
legal: add Apache-2.0 NOTICE DCO CLA and source headers
docs: add production readiness and go-live runbooks
```

## volunteer-platform

Backport reusable domain/security improvements only:

```text
security(db): backport membership and RLS boundary
feat(auth): backport account recovery foundations
feat(worker): backport atomic outbox lease processing
test(security): add PostgreSQL tenant isolation tests
ci(security): align DCO CodeQL secret scan and dependency gates
legal: align Apache-2.0 NOTICE DCO CLA
docs: identify Char-code as canonical integrated distribution
```

Avoid maintaining a second manually copied Char-code application.

## cloud-billing-anomaly

Keep billing credentials and raw billing data server-side:

```text
security(auth): enforce service and tenant authorization
security(secrets): harden billing credentials
security(network): restrict ingress to approved Char-code service path
feat(audit): add tenant-aware billing audit events
test(security): add billing cross-tenant tests
ci(security): add DCO CodeQL secret scan SBOM and provenance
legal: align Apache-2.0 NOTICE DCO CLA
```

## Desing-Azure-AI-Architecy-governed-agent

Treat governance results as tenant-owned security data:

```text
security(auth): enforce tenant-scoped governance access
security(network): restrict service ingress
feat(audit): add governance action audit trail
test(security): add privilege and tenant boundary tests
ci(security): add DCO CodeQL secret scan SBOM and provenance
legal: align Apache-2.0 NOTICE DCO CLA
docs: document governed AI trust boundaries
```

AI explanations must not replace deterministic policy evaluation.

## GitHub protection rollout

After code changes are merged:

```text
chore(github): add immutable repository rulesets
```

Then run:

```powershell
.\scripts\apply-github-rulesets.ps1 -Owner D-o-M-Pl
```

The apply script automatically invokes the verifier.
