# Operations: logs, persistence, and images

After `externalComponents`, the 3scale operator does not manage these databases. Day 2 checklist (persistent Redis, backups, digest): [06-day-2.md](06-day-2.md).

## Logs

Containers write to stdout/stderr (`loglevel notice` on Redis). Collect with cluster logging, for example ClusterLogForwarder filtering:

- `app=system-postgresql-external`
- `app=backend-redis-external`
- `app=system-redis-external`

There is no extra log volume in these manifests.

## Persistence

| Component | Mount | PVC |
|-----------|-------|-----|
| PostgreSQL | `/var/lib/pgsql/data` | `postgresql-data-external` |
| Redis backend | `/var/lib/redis/data` | `backend-redis-storage-external` |
| Redis system | `/var/lib/redis/data` | `system-redis-storage-external` |

Adjust `storage` and StorageClass to real 2.15 size. Schedule VolumeSnapshot and periodic `pg_dump` / `dump.rdb`.

Redis: restore mode only during cutover. In steady state, persist ConfigMap (`save` + `appendonly yes`).

## Images

Pin digest in the overlay or in `kustomize` `images:`. After an RHSCL CVE, update digest and rollout; the 3scale operator will not do it.

```bash
oc get deploy -n 3scale-db -o yaml | grep "image:"
```

## Network and security

NetworkPolicy allowing 5432 and 6379 **only** from the 3scale namespace. `registry.redhat.io` pull secret in `3scale-db`.
