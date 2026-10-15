# Externalize PostgreSQL (10 → 15) in-cluster

Same procedure as `website/docs/externalize-postgresql.md`. On Git Bash, [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md) only adds `MSYS_NO_PATHCONV=1`.

GitOps writes the Secret. Do not `oc patch` `system-database` or the APIManager. Copy the user and password into Vault (`secret/hub/3scale-postgresql`). ExternalSecret builds the URL with `urlquery`.

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
oc get deploy -n "$THREESCALE_NAMESPACE" -o json > "$HOME/3scale-replicas-before-cutover.json"
oc get deploy -n "$OPERATOR_NAMESPACE" -o name
```

On CSV 0.12 and 0.13 the operator Deployment is `threescale-operator-controller-manager-v2`. The name can change.

## 1. Scale down, leave embedded PostgreSQL at 1

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

## 2. Dump, checksum, and permissions

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- bash -c 'pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup'
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
sha256sum ./db_dump.backup
wc -c ./db_dump.backup
chmod 600 ./db_dump.backup
```

Compare the checksum after every later `oc cp`. Delete the dump when finished. Do not commit it.

## 3. Deploy PostgreSQL 15

Set `extraValueFiles` to `/values-cutover.yaml`. `externalComponents` stays false. Wait for `system-postgresql-external` at `1/1`. The chart NetworkPolicy limits 5432 and 6379 to namespaces `3scale` and `3scale-db`.

## 4. Restore

```bash
EXT_POD=$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')
oc cp ./db_dump.backup "$EXT_POD":/tmp/db_dump.backup -n "$DB_NAMESPACE"
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- sha256sum /tmp/db_dump.backup
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

`schema "public" already exists` is expected. Any other `pg_restore` error is a failed restore.

`GRANT CREATE` is the minimum. `ALTER SCHEMA ... OWNER TO system` is what lets `system-app-pre` run:

```bash
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c 'ANALYZE;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c \
  "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"
```

Compare `n_live_tup` with the embedded database. Run `ANALYZE` first.

## 5. Scale back

Restore replicas from `$HOME/3scale-replicas-before-cutover.json`. The operator does not raise `system-app` or `system-sidekiq` from 0; scale those two from the JSON. Scale embedded Redis back up for the next cycle. Scale embedded `system-postgresql` to 0 and **keep** the Deployment, Service, and PVC until 2.16 is accepted.

The smoke test runs after the Redis cycle, still on `threescale-2.15`.

## Rollback

Until `system-app-pre` succeeds on 2.16, set `extraValueFiles` back to `/values-215.yaml` and scale embedded PostgreSQL up. Do not delete its PVC. After that job, rollback is the fresh dump. See [07-rollback.md](07-rollback.md).
