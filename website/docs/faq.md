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

Run Redis in **restore mode** (`save ""`, `appendonly no`) only during cutover, and only because `values-cutover.yaml` sets `allowRestore: true`. Before returning traffic, switch to `/values-215-external.yaml` (`configMode: persist`). Channel 2.16 is `/values-216-external.yaml`. Without the persist step, a restart loses data.

Day 2 checklist (backups, digests, GitOps path): [Day 2 operations](day-2.md).

## The product looks down after the scale-down

The operator does not raise `system-app` or `system-sidekiq` from 0. Scale both from `$HOME/3scale-replicas-before-cutover.json`. CSV Succeeded and passing preflights do not start those pods. If `system-app-pre` fails with `ECONNREFUSED` to `backend-listener:3000`, scale `backend-listener` to 1 first. Full commands: [Upgrade operator to 2.16](upgrade-216.md).

## The developer portal says Access Restricted

That page, with a form posting to `/access_code`, is the portal access code. The route is serving.

## Search reindex pods are Error

`system-searchd-manticore-reindex` pods that failed before `system-app` was up can be deleted once a later reindex Job is Complete.

## Can I test on OpenShift 4.19 if production is on an earlier minor?

Yes. Use 4.19 to validate 2.16 with self-managed databases. On the cluster you will migrate, confirm the current OCP version is in the matrix for **both 2.15 and 2.16** (today: 4.12, 4.14, 4.16–4.20; 4.13 and 4.15 are not listed). If the Subscription uses manual approval, approve each InstallPlan. Sequence: latest 2.15 micro → externalize PostgreSQL and Redis **on 2.15** → verify 2.15 on the restore → 3scale operator 2.16 → OpenShift upgrade later. A separate APIcast operator is a different window.

## Where is the full procedure?

This site is the English procedure. Clone-friendly runbooks in the repository:

**English:** `docs/runbooks/en/` (`00`–`07`, including Windows variants `01-bis` / `02-bis`).

**Español:** `docs/runbooks/` (mismos números).

On Windows (Git Bash), use `docs/runbooks/01-bis-externalize-postgresql-windows.md` and `docs/runbooks/02-bis-externalize-redis-windows.md`. Operations reference: `docs/faq-externalizacion.md`. If cutover fails: [Rollback](rollback.md).
