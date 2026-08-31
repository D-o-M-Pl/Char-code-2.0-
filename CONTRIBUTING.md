# Contributing to Char-code 2.0

Thank you for contributing.

## License model

Char-code 2.0 is licensed under the Apache License, Version 2.0.

By submitting a contribution, you agree that your contribution may be distributed under the Apache License 2.0 and that you have the right to submit it.

## Developer Certificate of Origin (DCO)

Every commit must include a `Signed-off-by` line.

Example:

```text
Signed-off-by: Jan Kowalski <jan@example.com>
```

Use:

```bash
git commit -s
```

By signing off a commit, you certify the Developer Certificate of Origin in `DCO.md`.

Pull requests containing commits without a valid sign-off may be rejected.

## Contributor License Agreement (CLA)

For substantial contributions, maintainers may require acceptance of `CLA.md`.

The CLA does not transfer copyright ownership. Contributors retain copyright in their contributions while granting the project the rights needed to use and redistribute them under Apache 2.0.

## Contribution workflow

1. Fork the repository.
2. Create a focused branch.
3. Keep changes small and reviewable.
4. Add or update tests.
5. Run all validation locally.
6. Sign off every commit with DCO.
7. Open a pull request with a clear summary and security impact statement.
8. Do not include secrets, credentials, personal data, or third-party code without compatible licensing.

## Required checks

Before submitting:

```bash
npm run typecheck
npm run build
npm run test:e2e
npm run validate
```

For Windows changes also run:

```powershell
.\scripts\windows-launch.ps1 -Mode audit
```

For infrastructure changes, validate Bicep and deployment plans before production use.

## Security

Do not disclose exploitable vulnerabilities in public pull requests or issues.

Use the repository security reporting process for vulnerabilities.

## Coding standards

- Prefer simple, explicit code.
- Keep tenant isolation mandatory for organization-owned data.
- Do not bypass RBAC or PostgreSQL RLS.
- Do not expose secrets to browser code.
- Avoid long-lived credentials when Managed Identity is available.
- Add tests for cross-tenant access whenever a new tenant-owned resource is introduced.
- Treat audit and privacy flows as security-sensitive code.

## AI-generated contributions

AI-assisted code is allowed only if the contributor:

- reviews the code;
- verifies licensing/provenance;
- tests the result;
- takes responsibility for the contribution.

Do not submit generated code that may reproduce incompatible third-party source material.

## Copyright notices

New source files should include the repository Apache 2.0 copyright header.

## Pull request description

Include:

- purpose;
- implementation summary;
- tests;
- security/privacy impact;
- migration impact;
- backward compatibility;
- screenshots for UI changes where useful.
