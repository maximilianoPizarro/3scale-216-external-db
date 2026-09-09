# Operations FAQ

Common questions when you move from 3scale 2.15 (embedded databases) to 2.16 with PostgreSQL and Redis **in-cluster** but **outside the 3scale operator lifecycle**.

## Does “external” mean off-cluster?

No. *External* means the database sits **outside the 3scale operator lifecycle** — it can stay in-cluster (for example namespace `3scale-db`). Full explanation, operator reconciliation table, and scope limits: [Why this repo](why.md).

## Who operates logs and disk persistence?

After `externalComponents`, you own PostgreSQL and both Redis in `3scale-db` (pods, PVCs, images, backups, logs). The 3scale operator still manages `system-app`, APIcast, and Zync. Ownership matrix and steady-state checklist: [Day 2 operations](day-2.md). Motivation: [Why this repo](why.md).

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

This site is the English procedure. Clone-friendly runbooks in the repository:

**English:** `docs/runbooks/en/` (`00`–`07`, including Windows variants `01-bis` / `02-bis`).

**Español:** `docs/runbooks/` (mismos números).

On Windows (Git Bash), use `docs/runbooks/01-bis-externalize-postgresql-windows.md` and `docs/runbooks/02-bis-externalize-redis-windows.md`. Operations reference: `docs/faq-externalizacion.md`. If cutover fails: [Rollback](rollback.md).
