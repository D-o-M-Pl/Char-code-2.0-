# Automated GitHub Ruleset Deployment

The script:

```powershell
.\scripts\apply-github-rulesets.ps1
```

uses the GitHub REST API through `gh api`.

## Permissions

The authenticated token/account must have repository:

```text
Administration: write
```

for every target repository.

## Default repositories

```text
D-o-M-Pl/volunteer-platform
D-o-M-Pl/Char-code
D-o-M-Pl/cloud-billing-anomaly
D-o-M-Pl/Desing-Azure-AI-Architecy-governed-agent
```

Inaccessible/private repositories are skipped with a warning.

## Discover every owned repository

```powershell
.\scripts\apply-github-rulesets.ps1 `
  -Owner D-o-M-Pl `
  -DiscoverOwnedRepositories
```

This queries repositories visible to the authenticated GitHub account and filters them to the selected owner.

## Preview

```powershell
.\scripts\apply-github-rulesets.ps1 -DryRun
```

## Protection hierarchy

### Every branch

- deletion blocked;
- non-fast-forward / force push blocked.

### main

Additionally requires:

- pull request;
- CODEOWNERS;
- approval;
- DCO;
- CodeQL;
- Gitleaks;
- real PostgreSQL RLS.

### release/*

Same as `main`, with:

- 2 approvals;
- SBOM.

### v*

Immutable once created:

- updates blocked;
- deletion blocked.

### v2.0.0

Also protected by its own immutable tag ruleset.

The script is idempotent by ruleset name: it updates an existing repository-level ruleset or creates it when missing.
