# Day 2 operations

After you set `externalComponents`, the **3scale operator** still manages `system-app`, APIcast, and Zync. It no longer manages PostgreSQL (system) or Redis (system and backend). Whoever operates namespace `3scale-db` owns those Deployments, PVCs, images, backups, and NetworkPolicies.

Clone-friendly copy: `docs/runbooks/06-day-2.md`. Short reference: `docs/runbooks/04-ops-logs-persistencia-imagenes.md`.

!!! danger "Redis must stay in persist mode"
    Cutover uses `save ""` and `appendonly no` so Redis can load `dump.rdb`. In steady state the ConfigMap must come from `kustomize/bases/redis-config-persist` (`save` + `appendonly yes`).
    If GitOps points back at `redis-config-restore`, a restart **drops data**.

## Steady-state checklist

- [ ] Redis ConfigMap has `save` entries and `appendonly yes` (not `save ""`)
- [ ] GitOps `redis-config.path` is `kustomize/bases/redis-config-persist` (or you applied `*-persist`)
- [ ] Image digests are pinned (PostgreSQL 15 and Redis 7), not floating tags
- [ ] PVC size and `resources` match the 2.15 workload (lab values are examples)
- [ ] Scheduled `pg_dump` + VolumeSnapshot for PostgreSQL
- [ ] Scheduled Redis `SAVE` / `dump.rdb` / AOF + VolumeSnapshot
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
| Secrets that 3scale uses to connect | You, in namespace `3scale` |
| `system-app`, APIcast, Sidekiq, Searchd, Zync, `zync-database` | 3scale operator |
| `system-storage` (RWX) | 3scale operator / APIManager |

Deleting the `APIManager` must **not** delete PVCs in `3scale-db` (no `ownerReferences`; GitOps `prune: false`). Deleting namespace `3scale-db` **does** delete the data.

## Confirm Redis persistence

```bash
oc -n 3scale-db get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
```

Expect `save 900 1` (and the other `save` lines) and `appendonly yes`. Do **not** leave `save ""` or `appendonly no` after cutover.

Apply persist config:

```bash
# lab
oc apply -k kustomize/overlays/lab-persist

# generic StorageClass
oc apply -k kustomize/overlays/prod-persist
```

With GitOps, set `redis-config.path` to `kustomize/bases/redis-config-persist` in the external-db ApplicationSet, then restart:

```bash
oc -n 3scale-db rollout restart deployment/backend-redis-external deployment/system-redis-external
```

## Backups

| Component | What to copy | PVC |
|-----------|--------------|-----|
| PostgreSQL | `pg_dump` (custom format) + VolumeSnapshot | `postgresql-data-external` |
| Redis backend | `redis-cli SAVE`, then `dump.rdb` / AOF + snapshot | `backend-redis-storage-external` |
| Redis system | same | `system-redis-storage-external` |

Keep a copy of the connection secrets. After a restore as user `postgres`, re-apply the PostgreSQL 15 grant ([Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public)).

!!! warning "No high availability"
    Each database is **one replica**, `Recreate`, ReadWriteOnce. Red Hat does not support Redis Cluster for 3scale. Treat node drains and image rollouts as a maintenance window.

## Pin and patch image digests

The Deployments in `kustomize/bases/postgresql` and `kustomize/bases/redis-*` pin these linux/amd64 digests, resolved from `registry.redhat.io` on 2026-10-15:

| Image | Digest |
|-------|--------|
| `registry.redhat.io/rhel9/postgresql-15` | `sha256:242c66cfab1873ecbde84ba8c8bf7488b1c40a820f41820d76efa58634519826` |
| `registry.redhat.io/rhel9/redis-7` | `sha256:81535d5fd51bc5e83108db6f86a15b6b22412922d4a590235d1fba56751b967a` |

The 3scale operator no longer triggers ImageChange on these Deployments. Stay inside the 2.16 matrix: PostgreSQL ≥ 15.0 for system, Redis ≥ 7.2. To move to a newer digest, change the `image` field on those three Deployments and roll them:

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc apply -k kustomize/bases/postgresql -n 3scale-db
oc apply -k kustomize/bases/redis-system -n 3scale-db
oc apply -k kustomize/bases/redis-backend -n 3scale-db
oc -n 3scale-db rollout status deployment/system-postgresql-external
oc -n 3scale-db rollout status deployment/backend-redis-external
oc -n 3scale-db rollout status deployment/system-redis-external
```

A CVE in these images is a rollout you schedule. It is an outage for that database.

## Capacity

Lab PVCs are `1Gi`. Lab memory limits are `2Gi`. Copy requests, limits, and `storage` from the 2.15 embedded Deployments. Do not copy the 32Gi Redis limit from the official guide if production uses less.

Watch PVC fill rate and Redis memory. Redis is in-memory.

## Network, logs, and secrets

- Allow TCP **5432** and **6379** only from the 3scale namespace.
- Collect stdout/stderr (`loglevel notice` on Redis). Filter on `app=system-postgresql-external`, `app=backend-redis-external`, `app=system-redis-external`. These manifests do not mount a log volume.
- Rotate passwords in **both** namespaces: `system-database` in `3scale-db` (pod env) and `URL` / Redis URLs in `3scale`. Then restart PostgreSQL and `system-app`.

## PostgreSQL 15 grant

!!! warning "Canonical grant command"
    Keep `USAGE, CREATE` on schema `public` for user `system`. If you restore a dump as `postgres` and skip this, `system-app-pre` fails with `permission denied for schema public`. Full command: [Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public).

## Ownership diagram

![Ownership and rollback paths](images/ownership-and-rollback.png)

Rollback before `system-app-pre` succeeds on 2.16: [Rollback](rollback.md). After that job, restore the fresh dump.

## GitOps pitfalls

| Risk | What to do |
|------|------------|
| ApplicationSet still lists `redis-config-restore` | Change the path to `redis-config-persist` after cutover. `selfHeal: true` will revert a manual ConfigMap edit. |
| `prune: true` | Keep `prune: false` so a sync cannot delete PVCs. |
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
