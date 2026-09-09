# Operations FAQ

Common questions when moving from 3scale 2.15 (embedded databases) to 2.16 with PostgreSQL and Redis **inside the cluster** but **outside the operator lifecycle**.

## Does “external” mean off-cluster?

No. In Red Hat documentation, *external* means the database is **not part of the 3scale installation** and **is not reconciled by the operator**. It can live in the same cluster, even the same namespace (not recommended). A dedicated namespace (`3scale-db` in this repo) is the usual pattern.

`zync-database` can remain an internal operator-managed component.

## Who operates logs and disk persistence?

After `externalComponents` is set, the 3scale operator **stops reconciling** the Deployment and PVC:

| Area | Owner |
|------|-------|
| Pod lifecycle (Deployment, probes, image) | Database operator (these manifests / GitOps) |
| Persistence | PVC + StorageClass + VolumeSnapshot / backups |
| Logs | Container stdout/stderr → cluster logging stack |
| RHSCL image patches | Database operator (operator no longer triggers ImageChange) |
| Connection from 3scale | Secrets in the 3scale namespace |

Deleting the `APIManager` must not delete external PVCs. Resources in this package have no `ownerReferences` to the APIManager.

## Which image versions to pin?

2.16 preflight (checked every ~10 minutes):

- PostgreSQL ≥ 15.0 (system)
- Redis ≥ 7.2 (system + backend)

Images used in the official guide and this repo:

- `registry.redhat.io/rhel9/postgresql-15`
- `registry.redhat.io/rhel9/redis-7`

Pin **SHA-256 digests** from the Red Hat catalog, not floating tags.

## Redis restore vs persistence

Redis runs in **restore mode** (`save ""`, `appendonly no`) only during cutover to load `dump.rdb`. Afterwards switch to persistence (`lab-persist` overlay or `redis-config-persist`). Without that step, a restart loses data.

## Can I test on OpenShift 4.19 if production is on an earlier minor?

Yes, to validate 2.16 with self-managed databases. On the cluster you will migrate, confirm the current OCP version is in the matrix for **both 2.15 and 2.16**. Sequence: latest 2.15 micro → externalize PG and Redis **on 2.15** → operator 2.16 → OCP upgrade later.

## Where is the full procedure?

Detailed runbooks (Spanish) in the repository:

1. `docs/runbooks/00-secuencia-y-matriz.md`
2. `docs/runbooks/01-externalize-postgresql.md`
3. `docs/runbooks/02-externalize-redis.md`
4. `docs/runbooks/03-upgrade-215-to-216.md`
5. `docs/runbooks/04-ops-logs-persistencia-imagenes.md`

Operations reference: `docs/faq-externalizacion.md`.
