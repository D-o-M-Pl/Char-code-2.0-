# Azure Production Deployment

Production deployment is triggered only after the workflow named `Production Release Gate` completes successfully.

The deployment workflow does not rebuild source code. It downloads the `verified-production-release` manifest produced by the gate and deploys the exact container image digests already verified with Cosign.

## Required GitHub environment variables

Configure on the `production` environment:

```text
AZURE_DEPLOY_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_API_APP_NAME
AZURE_WEB_APP_NAME
PRODUCTION_URL
```

Use an Azure federated credential for the GitHub `production` environment.

Recommended production protection:

- required reviewers;
- prevent self-review;
- restrict deployment branches/tags;
- disable administrator bypass where operationally possible.

## Azure permissions

The deployment identity should receive only the permissions required to update/restart the two App Services.

Do not grant subscription-wide Owner permissions.

## Deployment invariant

```text
verified digest == deployed digest
```

Production must never rebuild an artifact after the verification gate.
