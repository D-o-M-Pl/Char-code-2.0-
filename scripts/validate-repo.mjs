// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

import fs from "node:fs";
import path from "node:path";

const required = [
  "apps/api/dist/index.js",
  "apps/web/index.html",
  "packages/database/prisma/schema.prisma",
  "docker-compose.saas.yml",
  "docker-compose.windows.yml",
  "scripts/windows-launch.ps1",
  "installers/inno/CharCode.iss",
  "installers/wix/Package.wxs"
];

for (const file of required) {
  if (!fs.existsSync(path.resolve(file))) {
    throw new Error(`Missing required file: ${file}`);
  }
}

const schema = fs.readFileSync("packages/database/prisma/schema.prisma", "utf8");
for (const model of ["User", "Organization", "OrganizationMembership", "Task", "PasswordResetToken", "MfaRecoveryCode"]) {
  if (!schema.includes(`model ${model} {`)) throw new Error(`Prisma model missing: ${model}`);
}

console.log("Repository structural validation PASS");