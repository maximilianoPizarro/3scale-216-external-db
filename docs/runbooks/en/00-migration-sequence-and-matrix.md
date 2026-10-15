# Migration sequence 2.15 → 2.16

## Order

1. Test cluster: install operator 2.15 and the APIManager ([05-install-operator-lab.md](05-install-operator-lab.md)).
2. Confirm the matrix: OpenShift supported by 2.15 and 2.16; latest CSV on `threescale-2.15`.
3. Back up PVCs and secrets. A VolumeSnapshot of a live database is crash-consistent. EFS CSI does not implement VolumeSnapshot.
4. Capture replicas outside the repo: `oc get deploy -n 3scale -o json > "$HOME/3scale-replicas-before-cutover.json"`.
5. PostgreSQL cycle: scale down, dump, restore, `ANALYZE`, scale up. Leave embedded PostgreSQL at 0 and keep the PVC ([01-externalize-postgresql.md](01-externalize-postgresql.md)).
6. Redis cycle: another scale down, `SAVE`, `DBSIZE`, RDB, scale up. Keep the embedded PVCs ([02-externalize-redis.md](02-externalize-redis.md)).
7. Smoke test on 2.15 against the external databases.
8. Fresh dump of PostgreSQL and both Redis instances.
9. Channel `threescale-2.16` through `/values-216-external.yaml` ([03-upgrade-215-to-216.md](03-upgrade-215-to-216.md)). Run `SELECT version();` before the switch.
10. Upgrade OpenShift afterwards, if needed.
11. Day 2 ([06-day-2.md](06-day-2.md)).

On Git Bash, [01-bis](01-bis-externalize-postgresql-windows.md) and [02-bis](02-bis-externalize-redis-windows.md) only add `MSYS_NO_PATHCONV=1`.

Until `system-app-pre` on 2.16, rollback is scaling the embedded databases back up. After that, restore the fresh dump. There is no OLM downgrade. The lab dump was 719027 bytes (a small database).

| File | When |
|------|------|
| `values-215.yaml` | Install. Channel `threescale-2.15`, embedded databases, `efs-sc`. |
| `values-cutover.yaml` | Both cycles. `allowRestore: true`, no Redis auth, `externalComponents` false. |
| `values-216-external.yaml` | After the fresh dump and the smoke test. Channel 2.16, `externalComponents`, auth, `persist`. |

EFS is the ReadWriteMany path (`efs-sc`). Without EFS, Local Storage Operator can create that same class; see [05-install-operator-lab.md](05-install-operator-lab.md). Do not run both.

Do not combine the 3scale jump and the OCP jump in the same window.

## Pattern value files

| File | When |
|------|------|
| `values-215.yaml` | Install. Channel `threescale-2.15`, embedded databases, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Maintenance window. External databases, Redis `configMode: restore`, `externalComponents` false. |
| `values-216-external.yaml` | After restore and portal checks. Channel `threescale-2.16`, `externalComponents`, Redis auth, `configMode: persist`. |

A ReadWriteMany StorageClass named `efs-sc` is required. Do not apply `hub-215.yaml` without it.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

## Summary matrix (2.16)

Always consult the official article; reference values:

- OpenShift: 4.14, 4.16, 4.17, 4.18, 4.19 (4.20+ in later 2.16 micros)
- PostgreSQL: 14, 15 (upgrade preflight requires ≥ 15.0 for system)
- Redis: 7.2 (two instances)
- Zync DB: may remain internal

Oracle: review 2.16.1 notes before planning the jump if the system DB is Oracle.
