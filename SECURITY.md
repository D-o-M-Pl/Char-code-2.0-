# Security Policy

## Supported versions

Security fixes are applied to the current `main` branch and the latest production release.

| Version | Supported |
| --- | --- |
| Latest production release | Yes |
| `main` | Yes |
| Older releases | Best effort only |

## Reporting a vulnerability

Do not open public issues for exploitable vulnerabilities.

Report security issues privately using GitHub Security Advisories:

1. Open the repository.
2. Go to **Security**.
3. Choose **Advisories**.
4. Select **Report a vulnerability**.

If private reporting is unavailable, contact the repository owner through a trusted private channel.

Do not include secrets, credentials, personal data, production tokens, or unnecessary exploit payloads.

## What to include

Please include:

- affected component;
- affected version or commit;
- vulnerability type;
- impact;
- reproduction steps;
- proof of concept when necessary;
- suggested mitigation if known.

## Response process

The maintainers will:

1. acknowledge the report;
2. assess severity and affected scope;
3. prepare a fix in a private branch when appropriate;
4. validate the fix with tests;
5. coordinate release and disclosure;
6. publish a security advisory when needed.

## Security boundaries

Changes involving the following areas require extra review:

- authentication;
- MFA;
- password recovery;
- session handling;
- tenant isolation;
- PostgreSQL RLS;
- authorization and RBAC;
- secrets;
- Azure Key Vault;
- billing integration;
- audit logging;
- document storage;
- GDPR data export/deletion;
- CI/CD credentials;
- infrastructure-as-code.

## Secrets

Never commit:

- `.env`;
- API keys;
- JWT secrets;
- cloud credentials;
- database passwords;
- private certificates;
- MFA encryption keys.

Production secrets must use a secrets manager such as Azure Key Vault and should use Managed Identity where possible.

## Dependency vulnerabilities

Security updates for direct and transitive dependencies should be prioritized based on exploitability and exposure, not only CVSS score.

## Security testing

Production changes should pass:

- typecheck;
- build;
- E2E;
- tenant-isolation tests;
- dependency audit;
- secret scanning;
- CodeQL or equivalent static analysis;
- infrastructure validation where applicable.

## Safe harbor

Good-faith security research that avoids privacy violations, service disruption, destructive testing, and data exfiltration is welcome when responsibly disclosed.
