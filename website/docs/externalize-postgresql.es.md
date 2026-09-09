# Externalizar PostgreSQL

Seguir el capítulo oficial *PostgreSQL 10 upgrade — On-cluster*. Esta página resume el procedimiento con los manifiestos de este repositorio. Runbook Linux completo: `docs/runbooks/01-externalize-postgresql.md`.

!!! tip "Windows / Git Bash"
    Leer primero [Windows / Git Bash](windows.es.md). Usar la pestaña **Windows / Git Bash** donde los comandos difieren. Exportar `MSYS_NO_PATHCONV=1` en cada shell.

## Variables

=== "Linux"

    ```bash
    export THREESCALE_NAMESPACE=3scale
    export OPERATOR_NAMESPACE=3scale
    export DB_NAMESPACE=3scale-db
    oc project "$THREESCALE_NAMESPACE"
    ```

=== "Windows / Git Bash"

    ```bash
    export MSYS_NO_PATHCONV=1
    export THREESCALE_NAMESPACE=3scale
    export OPERATOR_NAMESPACE=3scale
    export DB_NAMESPACE=3scale-db
    oc project "$THREESCALE_NAMESPACE"
    ```

Capturar las réplicas **antes** de escalar a 0 (lista completa en el runbook).

## 1. Escalar 3scale y el operador 3scale

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Dejar `system-postgresql` en 1 réplica.

## 2. Dump

=== "Linux"

    ```bash
    POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
    oc exec "$POSTGRES_POD" -- pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup
    oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
    ```

=== "Windows / Git Bash"

    ```bash
    POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
    oc exec "$POSTGRES_POD" -- bash -c 'pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup'
    oc cp "${POSTGRES_POD}:/tmp/db_dump.backup" ./db_dump.backup
    ```

    `tar: Removing leading '/' from member names` es esperado. El archivo local debe empezar por la magia `PGDMP` y pesar más que 0.

## 3. Desplegar PostgreSQL 15

```bash
DB_USER=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_USER}' | base64 -d)
DB_PASSWORD=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
oc create namespace "$DB_NAMESPACE" --dry-run=client -o yaml | oc apply -f -
oc create secret generic system-database \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  -n "$DB_NAMESPACE"
oc apply -k kustomize/bases/postgresql -n "$DB_NAMESPACE"
```

Si `base64 -d` falla en Git Bash, usar `base64 --decode`. Comprobar que `DB_USER` y `DB_PASSWORD` no estén vacíos antes de que el pod inicialice el PVC.

Desplegar **solo** PostgreSQL 15 primero. No aplicar aún el overlay `lab` completo. Ese overlay también crea Redis 7. Esperar `system-postgresql-external` en `1/1`.

## 4. Restore

=== "Linux"

    ```bash
    oc cp ./db_dump.backup "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')":/tmp -n "$DB_NAMESPACE"
    oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
      bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
    ```

=== "Windows / Git Bash"

    Poner el nombre de archivo en el destino remoto. Un `oc cp ... :/tmp` suelto lo reescribe Git Bash.

    ```bash
    PG15_POD=$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')
    oc cp ./db_dump.backup "${PG15_POD}:/tmp/db_dump.backup" -n "$DB_NAMESPACE"
    oc rsh -n "$DB_NAMESPACE" "$PG15_POD" \
      bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
    ```

El aviso `schema "public" already exists` es esperado.

### GRANT CREATE en schema `public`

PostgreSQL 15 no concede `CREATE` en el schema `public` al usuario de la aplicación. Sin este paso, el Job `system-app-pre` falla en el salto a 2.16 con `permission denied for schema public`.

=== "Linux"

    ```bash
    oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
      psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
    ```

=== "Windows / Git Bash"

    ```bash
    oc exec -n "$DB_NAMESPACE" "$PG15_POD" -- bash -c \
      'psql -U postgres -d system -c "GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;"'
    ```

## 5. Parchear el secret y el APIManager

```bash
oc get secret system-database -n "$THREESCALE_NAMESPACE" -o yaml > system-database-secret.yaml
DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@system-postgresql-service.${DB_NAMESPACE}.svc.cluster.local/system"
oc patch secret system-database -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"URL\":\"$DB_URL\"}}"
APIMANAGER_NAME=$(oc get apimanager -n "$THREESCALE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"system": {"database": true}}}}'
```

Eso desconecta el reconcile del operador 3scale sobre el PostgreSQL embebido y su PVC.

## 6. Subir y validar

Volver a subir **Redis embebido** (`backend-redis`, `system-redis`) antes del runbook de Redis. Restaurar el resto de réplicas. Luego validar portales y APIs.

Tras confirmar los datos, borrar el Deployment, PVC y Service de PostgreSQL embebido.

!!! danger "No commitear secrets ni dumps"
    No commitear archivos `*-secret.yaml`, `*.backup` ni `*.rdb`.
