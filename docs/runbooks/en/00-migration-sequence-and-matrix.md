# Migration sequence 2.15 → 2.16

## Order

1. Lab cluster: install operator 2.15 and APIManager ([05-install-operator-lab.md](05-install-operator-lab.md)).
2. Confirm the matrix: OpenShift supported by 2.15 and 2.16; latest CSV on channel `threescale-2.15`. The 2.16 upgrade guide lists 4.12, 4.14, 4.16, 4.17, 4.18, 4.19, and 4.20 today. 4.13 and 4.15 are not listed. If the Subscription uses manual approval, approve each InstallPlan: the next one appears only after the previous one installed.
3. Back up PVCs and secrets. A VolumeSnapshot of a live database is crash-consistent. The EFS CSI driver does not implement VolumeSnapshot.
4. Before the first scale-down: capture replicas (`oc get deploy -n 3scale -o json > "$HOME/3scale-replicas-before-cutover.json"`) and record account, service, and application counts from the portal or API. Copy PVC size and requests/limits from the running embedded Deployments; do not copy the guide example (1Gi / 32Gi Redis limit).
5. PostgreSQL cycle: scale down, dump, restore, `ANALYZE`, `ALTER SCHEMA public OWNER TO system`, scale embedded Redis back up for the next cycle. Leave embedded PostgreSQL at 0 and keep its Deployment, Service, and PVC ([01-externalize-postgresql.md](01-externalize-postgresql.md)).
6. Redis cycle: another scale down, `SAVE`, `DBSIZE`, RDB, load into Redis 7, `BGREWRITEAOF` and wait for `aof_rewrite_in_progress:0`. Keep the embedded PVCs ([02-externalize-redis.md](02-externalize-redis.md)).
7. Switch to `/values-215-external.yaml` (channel 2.15, `externalComponents`, auth, `persist`) before returning traffic. Confirm `appendonly yes` and the same `DBSIZE` on the new pod.
8. Verification on 2.15 against the restored databases: Admin Portal, Developer Portal, a new account, one APIcast call, analytics chart with historical traffic, and counts against the pre-window snapshot. The chart confirms the `backend-redis` RDB. A new call only proves write.
9. Fresh dump of PostgreSQL and both Redis instances.
10. Channel `threescale-2.16` via `/values-216-external.yaml` ([03-upgrade-215-to-216.md](03-upgrade-215-to-216.md)). That file only switches the channel. Run `SELECT version();` before the switch. If a separate APIcast operator exists, its 2.16 channel is a different window (chapter 2 of the guide).
11. OpenShift upgrade afterward, if needed.
12. Day 2 ([06-day-2.md](06-day-2.md)).

On Git Bash, [01-bis](01-bis-externalize-postgresql-windows.md) and [02-bis](02-bis-externalize-redis-windows.md) only add `MSYS_NO_PATHCONV=1`.

Until `system-app-pre` on 2.16, rollback is scaling the embedded databases back up. Do not delete their PVCs at the end of the PostgreSQL and Redis cycles. After that job, restore the fresh dump. There is no OLM downgrade. The lab dump was 719027 bytes (a small database).

| File | When |
|------|------|
| `values-215.yaml` | Install. Channel `threescale-2.15`, embedded databases, `efs-sc`. |
| `values-cutover.yaml` | Both cycles. `allowRestore: true`, no Redis auth, `externalComponents` false. |
| `values-215-external.yaml` | After RDB and `BGREWRITEAOF`. Channel 2.15, `externalComponents`, auth, `persist`. 3scale reads the new databases. |
| `values-216-external.yaml` | After the fresh dump and the 2.15 verification. Channel `threescale-2.16` only. |

EFS is the ReadWriteMany path (`efs-sc`). Without EFS, Local Storage Operator can create that same class; see [05-install-operator-lab.md](05-install-operator-lab.md). Do not run both.

Do not combine the 3scale jump and the OCP jump in the same window. Do not combine a separate APIcast operator upgrade either.

## Pattern values

| File | When |
|------|------|
| `values-215.yaml` | Install. Channel `threescale-2.15`, embedded databases, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Maintenance window. External databases, Redis `configMode: restore`, `externalComponents` false. |
| `values-215-external.yaml` | After Redis restore. 2.15 on the external databases. |
| `values-216-external.yaml` | After 2.15 verification. Channel 2.16 only. |

EFS is the ReadWriteMany path (`efs-sc`). Without EFS, apply `examples/local-storage/localvolume.yaml` before `hub-215.yaml`. Do not apply both at once.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

## Matrix summary (2.16)

Always check the official article; reference values:

- OpenShift: 4.12, 4.14, 4.16, 4.17, 4.18, 4.19, 4.20 (4.13 and 4.15 are not listed)
- PostgreSQL: 14, 15 (upgrade preflight requires ≥ 15.0 for system)
- Redis: 7.2 (two instances)
- Zync DB: may stay internal

Oracle: review 2.16.1 notes before planning the jump if the system DB is Oracle.
