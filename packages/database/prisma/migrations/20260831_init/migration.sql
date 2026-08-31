-- Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'UserRole') THEN
    CREATE TYPE "UserRole" AS ENUM ('VOLUNTEER', 'ORGANIZATION_ADMIN', 'PLATFORM_ADMIN', 'SUPPORT');
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS "users" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "email" TEXT NOT NULL UNIQUE,
  "display_name" TEXT NOT NULL,
  "password_hash" TEXT NOT NULL,
  "role" "UserRole" NOT NULL DEFAULT 'VOLUNTEER',
  "mfa_enabled" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "organizations" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "name" TEXT NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "organization_memberships" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "organization_id" TEXT NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "user_id" TEXT NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "role" "UserRole" NOT NULL,
  CONSTRAINT "organization_memberships_organization_id_user_id_key" UNIQUE ("organization_id", "user_id")
);

CREATE TABLE IF NOT EXISTS "tasks" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "organization_id" TEXT NOT NULL REFERENCES "organizations"("id") ON DELETE CASCADE,
  "title" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'OPEN'
);

CREATE INDEX IF NOT EXISTS "tasks_organization_id_idx" ON "tasks"("organization_id");

CREATE TABLE IF NOT EXISTS "sessions" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "user_id" TEXT NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "token_hash" TEXT NOT NULL UNIQUE,
  "expires_at" TIMESTAMPTZ NOT NULL,
  "revoked_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "sessions_user_id_expires_at_idx" ON "sessions"("user_id","expires_at");

CREATE TABLE IF NOT EXISTS "password_reset_tokens" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "user_id" TEXT NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "token_hash" TEXT NOT NULL UNIQUE,
  "expires_at" TIMESTAMPTZ NOT NULL,
  "used_at" TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS "mfa_recovery_codes" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "user_id" TEXT NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "code_hash" TEXT NOT NULL UNIQUE,
  "used_at" TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS "audit_logs" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "actor_user_id" TEXT,
  "organization_id" TEXT,
  "action" TEXT NOT NULL,
  "correlation_id" TEXT NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "audit_logs_organization_id_created_at_idx"
ON "audit_logs"("organization_id","created_at");

CREATE TABLE IF NOT EXISTS "outbox_events" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "event_type" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "processed" BOOLEAN NOT NULL DEFAULT false,
  "available_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "claimed_at" TIMESTAMPTZ,
  "claim_expires_at" TIMESTAMPTZ,
  "claim_token" TEXT,
  "processed_at" TIMESTAMPTZ,
  "last_error" TEXT
);

CREATE INDEX IF NOT EXISTS "outbox_events_processed_available_claim_idx"
ON "outbox_events"("processed","available_at","claim_expires_at");
CREATE INDEX IF NOT EXISTS "outbox_events_claim_token_idx"
ON "outbox_events"("claim_token");


CREATE TABLE IF NOT EXISTS "notifications" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "outbox_event_id" TEXT UNIQUE,
  "user_id" TEXT,
  "channel" TEXT NOT NULL DEFAULT 'EMAIL',
  "recipient" TEXT NOT NULL,
  "subject" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "sent_at" TIMESTAMPTZ,
  "last_error" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "notifications_status_created_at_idx"
ON "notifications"("status","created_at");

CREATE TABLE IF NOT EXISTS "dead_letter_events" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  "outbox_id" TEXT,
  "event_type" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "error" TEXT NOT NULL,
  "attempts" INTEGER NOT NULL,
  "failed_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE "tasks" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "organization_memberships" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tasks_tenant_policy ON "tasks";
CREATE POLICY tasks_tenant_policy ON "tasks"
USING (
  current_setting('app.is_platform_admin', true) = 'true'
  OR "organization_id" = current_setting('app.tenant_id', true)
)
WITH CHECK (
  current_setting('app.is_platform_admin', true) = 'true'
  OR "organization_id" = current_setting('app.tenant_id', true)
);

DROP POLICY IF EXISTS memberships_tenant_policy ON "organization_memberships";
CREATE POLICY memberships_tenant_policy ON "organization_memberships"
USING (
  current_setting('app.is_platform_admin', true) = 'true'
  OR "organization_id" = current_setting('app.tenant_id', true)
)
WITH CHECK (
  current_setting('app.is_platform_admin', true) = 'true'
  OR "organization_id" = current_setting('app.tenant_id', true)
);


-- Runtime role boundary.
-- Migrations run with the owner/admin connection. The application runtime
-- receives a separate LOGIN role that is a member of char_code_app.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'char_code_app') THEN
    CREATE ROLE char_code_app NOLOGIN NOBYPASSRLS;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO char_code_app;
GRANT SELECT, INSERT, UPDATE, DELETE
ON "users",
   "organizations",
   "organization_memberships",
   "tasks",
   "sessions",
   "password_reset_tokens",
   "mfa_recovery_codes",
   "audit_logs",
   "outbox_events",
   "notifications",
   "dead_letter_events"
TO char_code_app;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO char_code_app;

ALTER TABLE "tasks" FORCE ROW LEVEL SECURITY;
ALTER TABLE "organization_memberships" FORCE ROW LEVEL SECURITY;