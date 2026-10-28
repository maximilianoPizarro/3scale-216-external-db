# Day 2 operations

After you set `externalComponents`, the **3scale operator** still manages `system-app`, APIcast, and Zync. It no longer manages PostgreSQL (system) or Redis (system and backend). Whoever operates namespace `3scale-db` owns those Deployments, PVCs, images, backups, and NetworkPolicies.

Clone-friendly copy: `docs/runbooks/06-day-2.md`. Short reference: `docs/runbooks/04-ops-logs-persistencia-imagenes.md`.

!!! danger "Redis must stay in persist mode"
    Cutover uses `save ""` and `appendonly no` so Redis can load `dump.rdb` (`threescale.redis.configMode: restore` in `values-cutover.yaml`). Before returning traffic, `configMode: persist` comes from `values-215-external.yaml` (`save` + `appendonly yes`). `values-216-external.yaml` only switches the channel.
    If the Pattern stays on `values-cutover.yaml`, a restart **drops data**.

## Steady-state checklist

- [ ] Redis ConfigMap has `save` entries and `appendonly yes` (not `save ""`)
- [ ] Pattern `extraValueFiles` is `/values-215-external.yaml` or `/values-216-external.yaml` (`threescale.redis.configMode: persist`)
- [ ] Image digests are pinned (PostgreSQL 15 and Redis 7), not floating tags
- [ ] PVC size and `resources` match the 2.15 workload (lab values are examples; do not copy the guide 32Gi Redis limit)
- [ ] `threescale.backup.enabled` is a choice. The chart ships a CronJob for `pg_dump` and `redis-cli SAVE` onto PVC `external-db-backup`, and that CronJob stays off (`enabled: false`)
- [ ] A VolumeSnapshot of a live database PVC is crash-consistent. EFS CSI does not implement VolumeSnapshot, so `system-storage` uses AWS Backup or a file copy
- [ ] Secrets `system-database`, `system-redis`, and `backend-redis` are backed up from namespace `3scale` **and** `system-database` from `3scale-db`
- [ ] You have run a restore drill at least once
- [ ] ClusterLogForwarder (or equivalent) collects stdout from the three DB pods
- [ ] NetworkPolicy allows 5432 and 6379 **only** from the 3scale namespace
- [ ] Pull secret for `registry.redhat.io` exists in `3scale-db`
- [ ] On-call knows that a node drain or image rollout of these Deployments is an outage (`Recreate`, 1 replica, RWO)

## Who owns what

| Area | Owner after `externalComponents` |
|------|----------------------------------|
| PostgreSQL and both Redis (pod, PVC, image, probes) | Database operator (`3scale-db` manifests / GitOps) |
| Secrets that 3scale uses to connect | Vault, through ExternalSecret. Do not hand-edit `system-database`, `system-redis`, or `backend-redis` |
| `system-app`, APIcast, Sidekiq, Searchd, Zync, `zync-database` | 3scale operator |
| `system-storage` (RWX) | 3scale operator / APIManager |

Deleting the `APIManager` must **not** delete PVCs in `3scale-db` (no `ownerReferences`; GitOps `prune: false`). Deleting namespace `3scale-db` **does** delete the data.

## Confirm Redis persistence

```bash
oc -n 3scale-db get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
```

Expect `save 900 1` (and the other `save` lines) and `appendonly yes`. Do **not** leave `save ""` or `appendonly no` after cutover.

`threescale.redis.configMode: persist` arrives with `values-215-external.yaml` and stays in `values-216-external.yaml`. Let the Pattern sync, then restart:

```bash
oc -n 3scale-db rollout restart deployment/backend-redis-external deployment/system-redis-external
```

## Backups

| Component | What to copy | PVC |
|-----------|--------------|-----|
| PostgreSQL | `pg_dump` (custom format) to a volume that is not `postgresql-data-external` | `postgresql-data-external` |
| Redis backend | `redis-cli SAVE`, then copy `dump.rdb` off the database volume | `backend-redis-storage-external` |
| Redis system | same | `system-redis-storage-external` |

Keep a copy of the connection secrets. After a restore as user `postgres`, re-apply the PostgreSQL 15 grant ([Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public)).

!!! warning "No high availability"
    Each database is **one replica**, `Recreate`, ReadWriteOnce. Red Hat does not support Redis Cluster for 3scale. Treat node drains and image rollouts as a maintenance window.

## Pin and patch image digests

The 3scale operator no longer triggers ImageChange on these Deployments. Pin SHA-256 digests from the [Red Hat catalog](https://catalog.redhat.com/). This repo pins PostgreSQL 15 because the operator preflight requires ≥ 15.0, and Redis 7.2. Images are `registry.redhat.io/rhel9/postgresql-15` and `registry.redhat.io/rhel9/redis-7`.

Set `threescale.images.postgresql` and `threescale.images.redis` in `values-global.yaml` to `registry.redhat.io/...@sha256:<digest>`. Procedure: [Pin image digests](image-digests.md).

Inventory and rollout:

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc -n 3scale-db rollout status deployment/system-postgresql-external
oc -n 3scale-db rollout status deployment/backend-redis-external
oc -n 3scale-db rollout status deployment/system-redis-external
```

A CVE in those images is a rollout you schedule. It is an outage for that database. `maxmemory` and the Redis eviction policy are an operator decision. This repo does not set a value.

## Capacity

Lab PVCs are `1Gi`. Lab memory limits are `2Gi`. Copy requests, limits, and `storage` from the 2.15 embedded Deployments. Do not copy the 32Gi Redis limit from the official guide if production uses less.

Watch PVC fill rate and Redis memory. Redis is in-memory.

## Network, logs, and secrets

- Chart `external-db` applies a NetworkPolicy that allows TCP **5432** and **6379** only from namespaces `3scale` and `3scale-db`.
- Collect stdout/stderr (`loglevel notice` on Redis). Filter on `app=system-postgresql-external`, `app=backend-redis-external`, `app=system-redis-external`. These manifests do not mount a log volume.
- Rotate passwords in Vault. ExternalSecret refreshes `system-database` in `3scale-db` and the connection Secrets in `3scale`. Do not hand-edit those Secrets. Then restart PostgreSQL and `system-app`. See [Credential rotation](credential-rotation.md).

## PostgreSQL 15 grant

!!! warning "Canonical grant command"
    Keep `USAGE, CREATE` on schema `public` for user `system`. If you restore a dump as `postgres` and skip this, `system-app-pre` fails with `permission denied for schema public`. Full command: [Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public).

## Ownership diagram

![Ownership and rollback paths](images/ownership-and-rollback.png)

Rollback before `system-app-pre` succeeds on 2.16: [Rollback](rollback.md). After that job, restore the fresh dump.

## GitOps pitfalls

| Risk | What to do |
|------|------------|
| Pattern still on `values-cutover.yaml` | Switch `extraValueFiles` to `/values-215-external.yaml` before returning traffic, then to `/values-216-external.yaml` after the 2.15 verification. |
| `prune: true` | Keep global `prune: false`. The external database PVCs also carry `argocd.argoproj.io/sync-options: Prune=false`. Annotate PVC `system-storage` the same way after the operator creates it. |
| Mixing in-cluster GitOps and RHACM | Use one controller per destination. See [GitOps and RHACM](gitops.md). |

## Upgrade windows

Do not combine an OpenShift upgrade with a 3scale operator upgrade. A 2.16 micro release does **not** patch these databases. You patch PostgreSQL and Redis separately and keep versions in the [Supported Configurations](https://access.redhat.com/articles/2798521) matrix.

`zync-database` can stay internal. Do not fold it into the `3scale-db` runbook.

## Next steps

- [Rollback](rollback.md)
- [Official documentation](official-docs.md)
- [Operations FAQ](faq.md)
- [GitOps and RHACM](gitops.md)
- [Upgrade operator to 2.16](upgrade-216.md)
