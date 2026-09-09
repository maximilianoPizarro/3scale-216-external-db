# Operations FAQ

Common questions when you move from 3scale 2.15 (embedded databases) to 2.16 with PostgreSQL and Redis **in-cluster** but **outside the 3scale operator lifecycle**.

## Does “external” mean off-cluster?

No. In Red Hat documentation, *external* means the database is **not part of the 3scale installation**. The 3scale operator does not reconcile it. The database can live in the same cluster, even in the same namespace (not recommended). A dedicated namespace (`3scale-db` in this repo) is the usual pattern.

`zync-database` can remain an internal operator-managed component.

## Who operates logs and disk persistence?

After you set `externalComponents`, the 3scale operator **stops reconciling** the Deployment and PVC:

| Area | Owner |
|------|-------|
| Pod lifecycle (Deployment, probes, image) | Whoever operates the databases (these manifests / GitOps) |
| Persistence | PVC + StorageClass + VolumeSnapshot / backups |
| Logs | Container stdout/stderr → cluster logging stack |
| RHSCL image patches | Whoever operates the databases (the 3scale operator no longer triggers ImageChange) |
| Connection from 3scale | Secrets in the 3scale namespace |

Deleting the `APIManager` must not delete external PVCs. Resources in this package have no `ownerReferences` to the APIManager.

## Which image versions to pin?

!!! warning "Preflight requirement"
    PostgreSQL ≥ 15.0 (system) and Redis ≥ 7.2 (system + backend). The 3scale operator 2.16 checks this about every 10 minutes.

Images used in the official guide and this repo:

- `registry.redhat.io/rhel9/postgresql-15`
- `registry.redhat.io/rhel9/redis-7`

Pin **SHA-256 digests** from the Red Hat catalog. Do not pin floating tags.

## Redis restore vs persistence

Run Redis in **restore mode** (`save ""`, `appendonly no`) only during cutover to load `dump.rdb`. Afterwards switch to persistence (`lab-persist` overlay or `redis-config-persist`). Without that step, a restart loses data.

Day 2 checklist (backups, digests, GitOps path): [Day 2 operations](day-2.md).

## Can I test on OpenShift 4.19 if production is on an earlier minor?

Yes. Use 4.19 to validate 2.16 with self-managed databases. On the cluster you will migrate, confirm the current OCP version is in the matrix for **both 2.15 and 2.16**. Sequence: latest 2.15 micro → externalize PostgreSQL and Redis **on 2.15** → 3scale operator 2.16 → OpenShift upgrade later.

## Where is the full procedure?

Detailed runbooks (Spanish) in the repository:

1. `docs/runbooks/00-secuencia-y-matriz.md`
2. `docs/runbooks/01-externalize-postgresql.md`
3. `docs/runbooks/02-externalize-redis.md`
4. `docs/runbooks/03-upgrade-215-to-216.md`
5. `docs/runbooks/04-ops-logs-persistencia-imagenes.md`
6. `docs/runbooks/06-day-2.md`

On Windows, use [Windows / Git Bash](windows.md) and the `01-bis` / `02-bis` runbooks. Operations reference: `docs/faq-externalizacion.md`.
