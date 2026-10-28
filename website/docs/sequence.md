# Migration sequence

Linux/bash is the default. This page matches `docs/runbooks/00-secuencia-y-matriz.md`. On Git Bash, follow that same procedure with `MSYS_NO_PATHCONV=1` (`docs/runbooks/01-bis` and `02-bis` only add the Windows path rule).

Complete [Prerequisites](prerequisites.md) before step 1.

## Order of operations

![Migration sequence](images/migration-sequence.png)
*Diagram — phases: operator 2.15 → dump → `3scale-db` → restore → GRANT → persist on 2.15 → verification → channel 2.16 → day 2.*

![Namespace 3scale-db states](images/namespace-3scale-db-states.png)
*Diagram — empty → PG restore → Redis restore (`save ""`) → persist (`appendonly yes`) on 2.15 → verification → channel 2.16 → day 2.*

1. **Install 3scale 2.15** with embedded databases ([Install 3scale 2.15 (lab)](install-lab.md)).
2. **Confirm the matrix**: OpenShift supported by both 2.15 and 2.16 (today: 4.12, 4.14, 4.16–4.20; 4.13 and 4.15 are not listed); latest CSV on `threescale-2.15`. If the Subscription uses manual approval, approve each InstallPlan: the next one appears only after the previous one installed.
3. **Back up** PVCs and the connection secrets. A VolumeSnapshot of a live database PVC is crash-consistent. The EFS CSI driver does not implement VolumeSnapshot, so back up `system-storage` with AWS Backup or a file copy.
4. **Before the first scale-down**: capture replicas outside the repo, record account, service, and application counts from the portal or API, and copy PVC size and requests/limits from the running embedded Deployments (not the guide example 1Gi / 32Gi Redis limit):

    ```bash
    oc get deploy -n 3scale -o json > "$HOME/3scale-replicas-before-cutover.json"
    ```

5. **Cycle 1, PostgreSQL.** Scale the operator and 3scale components to 0 except `system-postgresql`. Dump, restore into PostgreSQL 15, `ANALYZE`, `ALTER SCHEMA public OWNER TO system`, compare table counts, scale the application back. The operator does not raise `system-app` or `system-sidekiq` from 0; use the JSON. Leave the embedded PostgreSQL Deployment at 0 and **keep** its PVC. [Externalize PostgreSQL](externalize-postgresql.md).
6. **Cycle 2, Redis.** Scale down again, except the embedded Redis you are dumping. `SAVE`, compare `LASTSAVE` and `DBSIZE`, copy `dump.rdb`, load it into Redis 7, `BGREWRITEAOF` and wait for `aof_rewrite_in_progress:0`. Leave embedded Redis at 0 and **keep** those PVCs. [Externalize Redis](externalize-redis.md).
7. **Persist on 2.15.** Set `extraValueFiles` to `/values-215-external.yaml` before returning traffic. That file sets `externalComponents`, Redis auth, and `configMode: persist`, and keeps channel `threescale-2.15`. Confirm `appendonly yes` and the same `DBSIZE`.
8. **Verification on 2.15** against the restored databases: Admin Portal, Developer Portal, create and read one account, one APIcast call, analytics chart with historical traffic, and counts against the pre-window snapshot. The chart confirms the `backend-redis` RDB. A new call only proves write.
9. **Fresh dump** of PostgreSQL and both Redis instances immediately before the channel switch.
10. **Switch the channel** by setting Pattern `extraValueFiles` to `/values-216-external.yaml`. That file only sets `threescale-2.16`. Run `SELECT version();` on the server before the switch. If a separate APIcast operator exists, its 2.16 channel is a different window. [Upgrade operator to 2.16](upgrade-216.md).
11. **Upgrade OpenShift later**, if needed. Do not combine it with the 3scale upgrade.
12. **Day 2** in `3scale-db`: Redis `persist`, pinned digests, backups. [Day 2 operations](day-2.md).

Until `system-app-pre` has run on 2.16, rollback is scaling the embedded databases back up. Do not delete those PVCs at the end of the PostgreSQL and Redis cycles. After that job, new writes live only on the external database. Rollback is a restore from the fresh dump. There is no OLM downgrade.

The lab PostgreSQL dump was 719027 bytes. That figure is a small database, not a production estimate.

!!! warning "Do not combine upgrades"
    Do not run the 3scale upgrade and the OpenShift upgrade in the same maintenance window. Do not combine a separate APIcast operator upgrade either.

## Value files

| File | When |
|------|------|
| `values-215.yaml` | Install. Channel `threescale-2.15`, embedded databases, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Both dump/restore cycles. External databases exist. 3scale still uses the embedded ones. Redis `configMode: restore` only because this file sets `allowRestore: true`. No Redis auth. |
| `values-215-external.yaml` | After RDB and `BGREWRITEAOF`. Channel 2.15, `externalComponents`, auth, `persist`. 3scale reads the new databases. |
| `values-216-external.yaml` | After the fresh dump and the 2.15 verification. Channel `threescale-2.16` only. |

GitOps is the source of truth. `extraValueFiles` is the switch. Vault and ExternalSecret write the Secrets. Argo overwrites a manual `oc patch` of those Secrets or of the APIManager.

`values-216-singlenode.yaml` installs 2.16 directly on one node. It is not this migration.

## Deploy

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
```

During the window, set `extraValueFiles` to `/values-cutover.yaml`, then `/values-215-external.yaml`, and after verification to `/values-216-external.yaml`. See [Install with a Pattern CR](pattern-cr.md).
