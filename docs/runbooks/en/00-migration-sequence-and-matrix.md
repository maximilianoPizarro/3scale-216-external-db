# Migration sequence 2.15 → 2.16

## Order

1. Test cluster without 3scale: install operator 2.15 and APIManager ([05-install-operator-lab.md](05-install-operator-lab.md)).
2. Confirm matrix: OpenShift supported by 2.15 **and** 2.16; latest CSV on channel `threescale-2.15`.
3. Snapshot / backup PVCs and secrets (`system-database`, `system-redis`, `backend-redis`).
4. Maintenance window: scale operator 3scale and 3scale components to 0 **except** the databases being dumped.
5. Externalize PostgreSQL 10 → 15 in-cluster ([01-externalize-postgresql.md](01-externalize-postgresql.md); Git Bash: [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md)).
6. Externalize Redis 6 → 7 in-cluster ([02-externalize-redis.md](02-externalize-redis.md); Git Bash: [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md)).
7. Set `spec.externalComponents` on the APIManager.
8. Restore replicas, validate Admin Portal, Developer Portal, and APIcast.
9. Upgrade operator to channel `threescale-2.16` ([03-upgrade-215-to-216.md](03-upgrade-215-to-216.md)).
10. Upgrade OpenShift **afterward**, if applicable, per [Supported Configurations](https://access.redhat.com/articles/2798521).
11. Day 2 in `3scale-db`: persistent Redis, backups, digest ([06-day-2.md](06-day-2.md)).

If a step fails before you delete embedded resources: [07-rollback.md](07-rollback.md). Site: `website/docs/rollback.md`.

Do not combine the 3scale jump and the OCP jump in the same window.

## Lab vs target

The `lab` overlay uses example StorageClass `gp3-csi`. The `prod` overlay uses the cluster default StorageClass. The 3scale procedure is the same.

Deploy the new databases:

```bash
# GitOps phase 1: operator 2.15
oc apply -k gitops/
oc apply -k gitops/rhacm/                 # if the target is a managed cluster

# GitOps phase 2: databases (system-database secret in 3scale-db first)
oc apply -k gitops/external-db
oc apply -k gitops/rhacm/external-db

# without Argo CD
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs
oc apply -k kustomize/overlays/lab-apimanager
oc apply -k kustomize/overlays/lab
```

RHACM: [gitops/rhacm/README.md](../../../gitops/rhacm/README.md).

## Summary matrix (2.16)

Always consult the official article; reference values:

- OpenShift: 4.14, 4.16, 4.17, 4.18, 4.19 (4.20+ in later 2.16 micros)
- PostgreSQL: 14, 15 (upgrade preflight requires ≥ 15.0 for system)
- Redis: 7.2 (two instances)
- Zync DB: may remain internal

Oracle: review 2.16.1 notes before planning the jump if the system DB is Oracle.
