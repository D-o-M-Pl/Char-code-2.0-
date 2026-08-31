# Database Security Boundary

Production uses two database identities.

## Migration identity

`MIGRATION_DATABASE_URL`

Responsibilities:

- schema migrations;
- creating/altering RLS policies;
- table ownership;
- controlled administrative maintenance.

It must never be used by the application runtime.

## Runtime identity

`DATABASE_URL`

The login role must be a member of:

```text
char_code_app
```

and must remain:

```text
NOSUPERUSER
NOBYPASSRLS
```

Runtime access receives ordinary DML grants only.

Tenant-owned tables use:

```sql
ENABLE ROW LEVEL SECURITY;
FORCE ROW LEVEL SECURITY;
```

## Request transaction

Every tenant query must run in the same database transaction that sets:

```text
app.tenant_id
app.is_platform_admin
```

`set_config(..., true)` makes these settings transaction-local.

The application query intentionally does not add an `organizationId` filter in the RLS test path; this proves PostgreSQL itself rejects cross-tenant rows.

## Production rule

Never point `DATABASE_URL` at the PostgreSQL administrator/table-owner account.
