# Externalizar PostgreSQL

Esta página es el mismo procedimiento que `docs/runbooks/01-externalize-postgresql.md`. En Git Bash, exportar `MSYS_NO_PATHCONV=1` antes de las rutas de `oc cp` y `pg_dump`. `docs/runbooks/01-bis-externalize-postgresql-windows.md` solo agrega esa regla.

GitOps escribe el Secret de conexión. No hacer `oc patch` de `system-database` ni del APIManager. Argo pisa ese parche. Copiar el usuario y la contraseña embebidos a Vault (`secret/hub/3scale-postgresql`). ExternalSecret arma la URL con `urlquery`, así la contraseña no queda en el historial del shell.

Antes del primer scale-down, anotar desde el portal o la API la cantidad de cuentas, servicios y aplicaciones. Copiar el tamaño de los PVC y los requests/limits de los Deployments embebidos que están corriendo (`system-postgresql`, `system-redis`, `backend-redis`). Ponerlos en `threescale.storage.databaseSize` y `threescale.resources` antes del primer sync de `/values-cutover.yaml`. No copiar el 1Gi ni el límite 32Gi de Redis del ejemplo de la guía. Durante la ventana conviven un PostgreSQL más y dos Redis; los PVC embebidos siguen ocupando disco.

`system-storage` no entra en el dump. Zync sigue interno: `zync-database` vuelve a 1 al restaurar réplicas.

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
```

Antes del primer scale-down, guardar las réplicas fuera del repo. No depender de una lista escrita en el runbook:

```bash
oc get deploy -n "$THREESCALE_NAMESPACE" -o json > "$HOME/3scale-replicas-before-cutover.json"
```

El Deployment del operador en el namespace `3scale` es `threescale-operator-controller-manager-v2` en los CSV 0.12 y 0.13. Confirmar el nombre; puede cambiar:

```bash
oc get deploy -n "$OPERATOR_NAMESPACE" -o name
```

## 1. Escalar a 0 y dejar PostgreSQL embebido en 1

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Dejar `system-postgresql` en 1 réplica.

## 2. Dump, checksum y permisos del archivo

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- bash -c 'pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup'
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
sha256sum ./db_dump.backup
wc -c ./db_dump.backup
chmod 600 ./db_dump.backup
```

Anotar checksum y tamaño. Después de cada `oc cp` posterior, volver a correr `sha256sum` y comparar. Borrar el dump al terminar la migración. No commitearlo.

## 3. Desplegar PostgreSQL 15

Poner `extraValueFiles` del Pattern en `/values-cutover.yaml`. Ese archivo enciende el chart `external-db` y deja `externalComponents` en false. Esperar `system-postgresql-external` en `1/1`. El mismo chart levanta Redis 7 en `configMode: restore`. Cargar `dump.rdb` en el procedimiento de Redis antes de `/values-215-external.yaml`.

Una NetworkPolicy del chart permite TCP 5432 y 6379 solo desde los namespaces `3scale` y `3scale-db`.

## 4. Restore y integridad

```bash
EXT_POD=$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')
oc cp ./db_dump.backup "$EXT_POD":/tmp/db_dump.backup -n "$DB_NAMESPACE"
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- sha256sum /tmp/db_dump.backup
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

`schema "public" already exists` es esperado (PostgreSQL 15 crea `public` antes del restore). Cualquier otro error de `pg_restore` es un restore fallido. No tomar cualquier warning como éxito.

### GRANT CREATE en schema `public`

`GRANT CREATE` es el privilegio mínimo. `ALTER SCHEMA public OWNER TO system` es lo que deja correr las migraciones de `system-app-pre` como `system`. Aplicar los dos:

```bash
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c 'ANALYZE;'
oc exec -n "$DB_NAMESPACE" "$EXT_POD" -- psql -U postgres -d system -c \
  "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"
```

Comparar `n_live_tup` con la misma consulta en la base embebida. `ANALYZE` tiene que correr antes, si no los conteos quedan en cero.

## 5. Apuntar 3scale a la base externa

Quedarse en `/values-cutover.yaml` hasta terminar el ciclo de Redis. Los Secrets del namespace `3scale` siguen apuntando a las bases embebidas. Después de cargar Redis y correr `BGREWRITEAOF`, `/values-215-external.yaml` pone `externalComponents` y ExternalSecret reescribe las URL. No parchearlos a mano en el medio. El canal `threescale-2.16` es el archivo siguiente.

## 6. Volver a escalar la aplicación

Restaurar las réplicas desde `$HOME/3scale-replicas-before-cutover.json`. El operador 3scale no sube `system-app` ni `system-sidekiq` desde 0; escalar esos dos desde el JSON. Volver a escalar el Redis embebido a su conteo anterior para poder volcarlo en el ciclo de Redis.

Escalar `system-postgresql` embebido a 0. **Conservar** su Deployment, Service y PVC hasta que `system-app-pre` termine bien en 2.16. La guía oficial borra esos recursos al final del capítulo; en este procedimiento no. Borrarlos elimina el camino de rollback hasta ese Job.

Después correr el ciclo de Redis. La verificación de 2.15 contra el restore (Admin Portal, Developer Portal, cuenta nueva, APIcast, gráfico de analíticas histórico) es después de `/values-215-external.yaml`.

!!! danger "No commitear secrets ni dumps"
    Nunca commitear `*-secret.yaml`, `*.backup` ni `*.rdb`.
