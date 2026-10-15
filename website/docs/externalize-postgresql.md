# Externalize PostgreSQL

This page is the same procedure as `docs/runbooks/01-externalize-postgresql.md`. On Git Bash, set `MSYS_NO_PATHCONV=1` before `oc cp` and `pg_dump` paths. `docs/runbooks/01-bis-externalize-postgresql-windows.md` only adds that rule.

GitOps writes the connection Secret. Do not `oc patch` `system-database` or the APIManager. Argo overwrites that patch. Copy the embedded user and password into Vault (`secret/hub/3scale-postgresql`). ExternalSecret renders the URL with `urlquery`, so the password does not land in shell history.

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
```

Before the first scale-down, save replica counts outside the repo. Do not rely on a list typed in a runbook:

```bash
oc get deploy -n "$THREESCALE_NAMESPACE" -o json > "$HOME/3scale-replicas-before-cutover.json"
```

The operator Deployment in namespace `3scale` is `threescale-operator-controller-manager-v2` on CSV 0.12 and 0.13. Confirm the name; it can change:

```bash
oc get deploy -n "$OPERATOR_NAMESPACE" -o name
```

## 1. Scale down, keep embedded PostgreSQL up

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Leave `system-postgresql` at 1 replica.

## 2. Dump, checksum, and restrict the file

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- bash -c 'pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup'
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
sha256sum ./db_dump.backup
wc -c ./db_dump.backup
chmod 600 ./db_dump.backup
```

Record the checksum and the size. After every later `oc cp`, run `sha256sum` again and compare. Delete the dump when the migration is finished. Do not commit it.

## 3. Deploy PostgreSQL 15

Set Pattern `extraValueFiles` to `/values-cutover.yaml`. That file enables chart `external-db` and leaves `externalComponents` false. Wait for `system-postgresql-external` at `1/1`. The same chart starts Redis 7 in `configMode: restore`. Load `dump.rdb` in the Redis procedure before `/values-216-external.yaml`.

A NetworkPolicy in the chart allows TCP 5432 and 6379 only from namespaces `3scale` and `3scale-db`.

## 4. Restore and check integrity

```bash
EXT_POD=$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')
oc cp ./db_dump.backup "$EXT_POD":/tmp/db_dump.backup -n "$DB_NAMESPACE"
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- sha256sum /tmp/db_dump.backup
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

`schema "public" already exists` is expected (PostgreSQL 15 creates `public` before the restore). Any other `pg_restore` error is a failed restore. Do not treat every warning as success.

### Grant CREATE on schema `public`

`GRANT CREATE` is the minimum privilege. `ALTER SCHEMA public OWNER TO system` is what lets `system-app-pre` run its migrations as `system`. Apply both:

```bash
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c 'ANALYZE;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c \
  "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"
```

Compare `n_live_tup` with the same query on the embedded database. `ANALYZE` must run first or the counts stay at zero.

## 5. Point 3scale at the external database

Stay on `/values-cutover.yaml` until the Redis cycle finishes. The Secrets in namespace `3scale` still point at the embedded databases. After Redis is loaded, `/values-216-external.yaml` sets `externalComponents` and ExternalSecret rewrites the URLs. Do not patch them by hand in between.

## 6. Scale the application back

Restore replica counts from `$HOME/3scale-replicas-before-cutover.json`. Scale embedded Redis back to its previous count so the Redis cycle can dump it.

Scale embedded `system-postgresql` to 0. **Keep** its Deployment, Service, and PVC until the 2.16 upgrade has been accepted. Deleting them removes the rollback path.

Then run the Redis cycle. The smoke test (admin login, create and read an account, one APIcast call, Sidekiq not stuck) happens after both cycles, still on channel `threescale-2.15`.

!!! danger "Do not commit secrets or dumps"
    Never commit `*-secret.yaml`, `*.backup`, or `*.rdb` files.
