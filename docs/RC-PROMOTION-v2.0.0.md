# v2.0.0 RC Promotion

Workflow:

```text
v2.0.0-rc.1
    ↓
verify signed immutable API/Web digests
    ↓
staging slots
    ↓
security smoke tests
    ↓
production-approval environment
    ↓
production environment
    ↓
API staging → production swap
    ↓
Web staging → production swap
    ↓
production smoke
    ↓
verify deployed digests
```

If the production smoke fails after a swap, the workflow performs the reverse swap so the previous production release returns to the production slots.

## GitHub environment protection

Configure both:

```text
production-approval
production
```

with required reviewers and prevent self-review.

The production environment must also restrict deployable refs to approved release branches/tags.

## Database migration rule

Do not perform a destructive database migration inside the slot-swap workflow.

Database changes for `v2.0.0` must be:

- backward compatible with both old and new application versions during the promotion window;
- rehearsed in staging;
- applied before the application swap;
- independently recoverable.

Use expand/migrate/contract rather than a destructive one-step schema change.
