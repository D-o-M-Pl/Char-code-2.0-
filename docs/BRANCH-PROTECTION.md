# Production Branch Protection

## main

Enabled protections:

- block force pushes;
- block branch deletion;
- require pull requests;
- require 1 approving review;
- require CODEOWNERS review;
- dismiss stale reviews;
- require latest push approval;
- require review threads resolved;
- require branch up to date;
- require status checks before merge.

Required checks:

```text
DCO Sign-off
CodeQL Analyze
Gitleaks
Real PostgreSQL RLS
```

## release/*

Same protections, with 2 approvals and additional:

```text
Generate SBOM
```

## Apply in GitHub

```text
Settings
→ Rules
→ Rulesets
```

Keep enforcement set to `Active`.

The JSON files are stored in:

```text
.github/rulesets/main.json
.github/rulesets/release.json
```

GitHub matches status checks by exact job/check context name. Verify those names after the workflows have run at least once.
