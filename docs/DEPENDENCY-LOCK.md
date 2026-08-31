# Dependency Lockfile Requirement

The current artifact package was generated in an offline environment and does not contain a registry-resolved `package-lock.json`.

Top-level dependency versions are pinned exactly, but this is not equivalent to a lockfile.

Before `v2.0.0`:

1. On a trusted connected build machine run:

```bash
rm -rf node_modules
npm install
npm run prisma:generate
npm run prisma:validate
npm run typecheck
npm run build
npm run test:e2e
git add package-lock.json
git commit -s -m "build: lock npm dependency graph"
```

2. Change CI installation commands from:

```bash
npm install --no-audit --no-fund
```

to:

```bash
npm ci --ignore-scripts
```

where compatible, followed by explicit required generation/build scripts.

3. Review the lockfile in the same pull request.

Production release is **NO-GO** without a committed and reviewed lockfile.
