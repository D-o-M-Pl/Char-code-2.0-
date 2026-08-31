# Monitoring baseline

Production alerts:
- HTTP 5xx > 1% warning, > 5% critical.
- p95 API latency > 750 ms warning, > 1500 ms critical.
- pending outbox > 100 warning.
- any dead-letter event warning.
- PostgreSQL connections > 70% warning, > 90% critical.
- storage > 75% warning, > 90% critical.
- authentication failure anomaly.
- unusual cross-tenant 403 spike.

Initial SLO:
- availability: 99.9%;
- p95 normal CRUD: < 500 ms;
- RPO <= 15 minutes;
- RTO <= 4 hours.
