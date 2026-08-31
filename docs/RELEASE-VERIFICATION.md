# Release Verification

Char-code release artifacts use multiple independent integrity signals.

## SHA-256

Download the artifact and `SHA256SUMS.txt`.

Linux/macOS:

```bash
sha256sum -c SHA256SUMS.txt
```

Windows PowerShell:

```powershell
Get-FileHash .\CharCode-Setup.exe -Algorithm SHA256
```

Compare the result with the matching line in `SHA256SUMS.txt`.

## Sigstore/Cosign blob signature

Windows `.exe` and `.msi` files are accompanied by `.sigstore.json` bundles.

Example:

```bash
cosign verify-blob \
  --bundle CharCode-Setup.exe.sigstore.json \
  --certificate-identity-regexp '^https://github.com/.+/.github/workflows/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  CharCode-Setup.exe
```

Use the exact repository workflow identity in production verification policies.

## Container signatures

Container images are signed keylessly through GitHub Actions OIDC.

Example:

```bash
cosign verify \
  --certificate-identity-regexp '^https://github.com/OWNER/REPOSITORY/.github/workflows/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/OWNER/REPOSITORY/api@sha256:DIGEST
```

Always verify by immutable digest.

## GitHub Artifact Attestations

Release artifacts also receive GitHub build provenance attestations.

GitHub attestations provide cryptographically signed build provenance. Verify them with GitHub CLI where supported.

## SLSA provenance

Tagged releases generate SLSA provenance through the isolated `slsa-github-generator` reusable workflow.

Verify the SLSA provenance using `slsa-verifier` and the expected source repository/tag.

## Important

Sigstore signing proves workflow identity and artifact integrity. It is not Authenticode.

For Windows SmartScreen/reputation and traditional Windows publisher identity, use a separate Authenticode code-signing certificate or Azure Trusted Signing in addition to Sigstore.
