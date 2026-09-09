# Rollback

Use this page when cutover fails **before** you delete embedded Deployments and PVCs, or when the 3scale operator 2.16 upgrade loops on preflight. Clone-friendly copy: `docs/runbooks/en/07-rollback.md` (Spanish: `docs/runbooks/07-rollback.md`).

If embedded resources are already gone, rollback means **restore from backup** (PVC snapshot, `pg_dump`, `dump.rdb`), not flipping `externalComponents` back to embedded pods that no longer exist.

![Ownership and rollback paths](images/ownership-and-rollback.png)

## Who owns what

| Namespace | Operator manages | You manage |
|-----------|------------------|------------|
| `3scale` | `system-app`, APIcast, Zync, `zync-database`, `system-storage` | Connection secrets (`system-database`, `system-redis`, `backend-redis`) |
| `3scale-db` | Nothing from the 3scale operator after `externalComponents` | PostgreSQL 15, both Redis 7, PVCs, images, backups, NetworkPolicy |

See [Why this repo](why.md) for the full *external ≠ off-cluster* explanation and what the 3scale operator stops reconciling.

## PostgreSQL restore fails

1. Set `externalComponents.system.database` back to `false` on the APIManager.
2. Reapply embedded PostgreSQL in the APIManager spec if needed: `spec.system.database.postgresql: {}`.
3. Restore secret `system-database` from the backup you took (`system-database-secret.yaml`).
4. Scale up the 3scale operator and embedded `system-postgresql`.
5. Validate Admin Portal and APIs against embedded data.
6. **Do not** delete the new PostgreSQL PVC in `3scale-db` until embedded PostgreSQL is confirmed healthy.

## Redis RDB empty or restore fails

1. Set `externalComponents.system.redis` and `externalComponents.backend.redis` back to `false`.
2. Restore secrets `system-redis` and `backend-redis` from backup.
3. Scale embedded `backend-redis` and `system-redis` back up on 3scale 2.15.
4. Validate portals and API traffic.
5. **Do not** delete new Redis PVCs in `3scale-db` until embedded Redis is confirmed healthy.

If `dump.rdb` was empty on Git Bash, use `docs/runbooks/02-bis-externalize-redis-windows.md` (`MSYS_NO_PATHCONV=1`, `oc exec` + `cat`) and re-run [Externalize Redis](externalize-redis.md).

## 3scale operator 2.16 preflight loop

Symptoms: operator 2.16 installs but the instance upgrade never completes; version checks fail every ~10 minutes.

1. Confirm PostgreSQL ≥ 15.0 and Redis ≥ 7.2 on the external pods ([Upgrade operator to 2.16](upgrade-216.md#run-preflight-checks)).
2. Apply the PostgreSQL 15 grant if `system-app-pre` reports `permission denied for schema public` — see [Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public).
3. Delete the `system-app-pre` Job and let the operator recreate it.
4. **Do not** combine an OpenShift upgrade with the 3scale upgrade in the same window.
5. If versions cannot be fixed in time, stay on channel `threescale-2.15` until external databases meet preflight.

## GitOps rollback trap (Redis)

If Argo CD or RHACM still points `redis-config.path` at `kustomize/bases/redis-config-restore`, `selfHeal: true` reverts persist mode after cutover. A pod restart can **drop Redis data**. Switch to `redis-config-persist` before you treat the migration as done. See [GitOps pitfalls](gitops.md#gitops-pitfalls) and [Day 2 operations](day-2.md).

## Next steps

- [Migration sequence](sequence.md)
- [Day 2 operations](day-2.md)
- [Operations FAQ](faq.md)
