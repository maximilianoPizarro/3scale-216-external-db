# Externalizar PostgreSQL

Seguir el capítulo oficial *PostgreSQL 10 upgrade — On-cluster*. Esta página resume el procedimiento con los manifiestos de este repositorio. Runbook completo: `docs/runbooks/01-externalize-postgresql.md` (Git Bash: `docs/runbooks/01-bis-externalize-postgresql-windows.md`).

## Variables

```bash
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

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
```

## 3. Desplegar PostgreSQL 15

El ExternalSecret `system-database` en `3scale-db` escribe `DB_USER` y `DB_PASSWORD` desde Vault. Completar antes [Vault y External Secrets](vault-external-secrets.es.md) y esperar ese ExternalSecret en `SecretSynced`. No crear el Secret con `oc create secret`.

```bash
oc get externalsecret system-database -n "$DB_NAMESPACE"
oc apply -k kustomize/bases/postgresql -n "$DB_NAMESPACE"
```

Comprobar que las claves del Secret no estén vacías antes de que el pod inicialice el PVC.

Desplegar **solo** PostgreSQL 15 primero. No aplicar aún el overlay `lab` completo. Ese overlay también crea Redis 7. Esperar `system-postgresql-external` en `1/1`.

## 4. Restore

```bash
oc cp ./db_dump.backup "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')":/tmp -n "$DB_NAMESPACE"
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

El aviso `schema "public" already exists` es esperado.

### GRANT CREATE en schema `public`

PostgreSQL 15 no concede `CREATE` en el schema `public` al usuario de la aplicación. Sin este paso, el Job `system-app-pre` falla en el salto a 2.16 con `permission denied for schema public`.

```bash
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

## 5. Secret de conexión y APIManager

```bash
oc apply -k kustomize/overlays/lab-vault-components
APIMANAGER_NAME=$(oc get apimanager -n "$THREESCALE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"system": {"database": true}}}}'
```

El ExternalSecret escribe `URL` con `mergePolicy: Merge`. No parchear ese Secret a mano.

Eso desconecta el reconcile del operador 3scale sobre el PostgreSQL embebido y su PVC.

## 6. Subir y validar

Volver a subir **Redis embebido** (`backend-redis`, `system-redis`) antes del runbook de Redis. Restaurar el resto de réplicas. El operador no sube `system-app` ni `system-sidekiq` desde 0; escalar esos dos a mano. Luego validar portales y APIs.

Escalar `system-postgresql` embebido a 0. **Conservar** su Deployment, Service y PVC hasta que `system-app-pre` termine bien en 2.16. Borrarlos elimina el camino de rollback.

!!! danger "No commitear secrets ni dumps"
    No commitear archivos `*-secret.yaml`, `*.backup` ni `*.rdb`.
