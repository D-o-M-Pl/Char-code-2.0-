# Azure Artifact Signing configuration

Configure the following GitHub **Repository Variables**:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_ARTIFACT_SIGNING_ENDPOINT
AZURE_ARTIFACT_SIGNING_ACCOUNT
AZURE_ARTIFACT_SIGNING_PROFILE
```

Configure a GitHub OIDC federated credential on the Azure application.

Assign the signing identity the minimum required role on the signing account/profile:

```text
Artifact Signing Certificate Profile Signer
```

Do not use a long-lived Azure client secret when OIDC is available.

## Production deployment gate

The production deployment process must consume only a release tag that has passed:

```text
Production Release Gate / Production Artifact Gate
```

Run:

```text
Actions -> Production Release Gate -> Run workflow -> tag=vX.Y.Z
```

Configure the GitHub `production` environment with required reviewers.

A deployment workflow should use the verified immutable release tag/digests rather than rebuilding source code after this gate.
