# Externalizar PostgreSQL (10 → 15) in-cluster

Procedimiento único, el mismo que `website/docs/externalize-postgresql.es.md`. En Git Bash: [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md) solo agrega `MSYS_NO_PATHCONV=1`.

GitOps escribe el Secret. No hacer `oc patch` de `system-database` ni del APIManager. Copiar usuario y contraseña a Vault (`secret/hub/3scale-postgresql`). ExternalSecret arma la URL con `urlquery`.

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
oc get deploy -n "$THREESCALE_NAMESPACE" -o json > "$HOME/3scale-replicas-before-cutover.json"
oc get deploy -n "$OPERATOR_NAMESPACE" -o name
```

En CSV 0.12 y 0.13 el Deployment del operador es `threescale-operator-controller-manager-v2`. El nombre puede cambiar.

## 1. Escalar a 0 y dejar PostgreSQL embebido en 1

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

## 2. Dump, checksum y permisos

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- bash -c 'pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup'
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
sha256sum ./db_dump.backup
wc -c ./db_dump.backup
chmod 600 ./db_dump.backup
```

Comparar el checksum después de cada `oc cp`. Borrar el dump al terminar. No commitearlo.

## 3. Desplegar PostgreSQL 15

`extraValueFiles` pasa a `/values-cutover.yaml`. `externalComponents` sigue en false. Esperar `system-postgresql-external` en `1/1`. La NetworkPolicy del chart limita 5432 y 6379 a los namespaces `3scale` y `3scale-db`.

## 4. Restore

```bash
EXT_POD=$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')
oc cp ./db_dump.backup "$EXT_POD":/tmp/db_dump.backup -n "$DB_NAMESPACE"
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- sha256sum /tmp/db_dump.backup
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

`schema "public" already exists` es esperado. Otro error de `pg_restore` es un restore fallido.

`GRANT CREATE` es el mínimo. `ALTER SCHEMA ... OWNER TO system` es lo que deja correr `system-app-pre`:

```bash
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c 'ANALYZE;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c \
  "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"
```

Comparar `n_live_tup` con la base embebida. `ANALYZE` va primero.

## 5. Volver a escalar

Restaurar réplicas desde `$HOME/3scale-replicas-before-cutover.json`. Volver a subir Redis embebido para el ciclo siguiente. Escalar `system-postgresql` embebido a 0 y **conservar** Deployment, Service y PVC hasta aceptar 2.16.

El smoke test es después del ciclo de Redis, todavía en `threescale-2.15`.

## Rollback

Hasta que `system-app-pre` termine bien en 2.16: volver `extraValueFiles` a `/values-215.yaml` y escalar el PostgreSQL embebido. No borrar su PVC. Después de ese Job, el rollback es el dump fresco. Ver [07-rollback.md](07-rollback.md).
