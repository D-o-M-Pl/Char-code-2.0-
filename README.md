# Char-code 2.0

Canonical repository with two deployment profiles.

## 1. SaaS

```bash
docker compose -f docker-compose.saas.yml up --build
```

Target production architecture:

Browser/PWA -> Azure Front Door/WAF -> Web/BFF -> API -> private PostgreSQL.

## 2. Windows

Windows 10 x86 uses hosted Web/PWA.
Windows 10 x64 / Windows 11 x64 can use the local Docker profile.

```powershell
.\scripts\windows-launch.ps1 -Mode audit
.\scripts\windows-launch.ps1 -Mode local -Build
```

## Build

```bash
npm run typecheck
npm run build
npm run test:e2e
npm run validate
```

## Installer

Windows build machine:

```powershell
.\installers\build-installer.ps1 -Target all
```

Requires:
- Inno Setup 6 for `.exe`;
- WiX Toolset 5 for `.msi`.

The installer intentionally installs the launcher/configuration layer. The Windows x86 path opens the hosted application; the x64 path can launch Docker Desktop based local services.

## License

Copyright 2026 D-o-M-Pl.

Licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`.

The Apache License grants broad permissions to use, modify, and distribute the software subject to its terms. Trademark and branding rights are not granted by the license.

## Contributing

See:

- `CONTRIBUTING.md`
- `DCO.md`
- `CLA.md`
- `docs/contribution-licensing-flow.svg`

All source contributions must be compatible with Apache License 2.0 and follow the repository DCO/CLA policy.

## Repository security

See:

- `SECURITY.md`
- `.github/CODEOWNERS`
- `.github/workflows/dco.yml`
- `docs/BRANCH-PROTECTION.md`

## Supply-chain security

Enabled repository automation:

- Dependabot for npm, Docker and GitHub Actions;
- CodeQL security analysis;
- Gitleaks secret scanning;
- CycloneDX and SPDX SBOM generation;
- GitHub rulesets for `main` and `release/*`.

See `.github/rulesets/` and `docs/github-security-gate.svg`.

## Verified releases

Tagged releases include:

- SHA-256 checksums;
- Sigstore/Cosign signatures for Windows artifacts;
- keyless Cosign signatures for container images;
- GitHub build provenance attestations;
- SLSA provenance;
- SBOM artifacts.

Verification instructions: `docs/RELEASE-VERIFICATION.md`.

Note: Sigstore signatures are complementary to Windows Authenticode. Use a trusted Authenticode/Azure Trusted Signing certificate as well when publisher identity and SmartScreen reputation are required.

## Windows publisher signing and production verification

Windows `.exe` and `.msi` releases are configured for Azure Artifact Signing (formerly Trusted Signing) Authenticode signatures using GitHub OIDC.

Production release verification is fail-closed and validates SHA-256, Authenticode, Sigstore, GitHub artifact attestations and SLSA provenance before the protected `production` environment can approve deployment.

See `docs/AZURE-ARTIFACT-SIGNING.md` and `docs/production-artifact-trust-gate.svg`.

## Production Readiness 1.0

Production deployment is automatic only after the `Production Release Gate` completes successfully. The Azure deploy job consumes immutable, verified GHCR image digests and does not rebuild source code.

Final audit: `docs/PRODUCTION-READINESS-1.0.md`.

Azure deployment details: `docs/AZURE-PRODUCTION-DEPLOYMENT.md`.

## v2.0.0 release rehearsal

Final release material:

- `docs/GO-LIVE-v2.0.0.md`
- `scripts/smoke-test.mjs`

SaaS/canonical repositories also include:

- `.github/workflows/azure-staging-rehearsal.yml`
- `docs/STAGING-REHEARSAL.md`

The staging rehearsal deploys signed images by immutable digest, runs security smoke tests, and can prove the rollback path against the previous staging baseline.
