# Copyright 2026 D-o-M-Pl
# Licensed under the Apache License, Version 2.0.

FROM node:22-alpine AS build
WORKDIR /app

COPY package.json ./
COPY apps/api/package.json ./apps/api/package.json
COPY tsconfig.base.json ./
COPY packages/database/prisma ./packages/database/prisma

RUN npm install --no-audit --no-fund
RUN npm run prisma:generate

COPY apps/api/tsconfig.json ./apps/api/tsconfig.json
COPY apps/api/src ./apps/api/src

RUN npm run build
RUN npm prune --omit=dev

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
ENV DATABASE_MODE=prisma
ENV HOST=0.0.0.0
ENV PORT=3001

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/apps/api/dist ./apps/api/dist
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/apps/api/package.json ./apps/api/package.json

USER node
EXPOSE 3001
CMD ["node", "apps/api/dist/index.js"]
