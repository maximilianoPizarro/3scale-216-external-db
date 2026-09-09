# Externalizar PostgreSQL (10 → 15) in-cluster

Sigue el capítulo *PostgreSQL 10 upgrade - On-cluster* de la guía oficial de 2.16. Resumen operativo con los manifiestos de este repo. Comandos para **Linux/macOS**. En Git Bash (Windows): [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md).

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
```

Con el overlay `lab-operator`, operador y APIManager viven en `3scale`. Guardar réplicas antes de escalar a 0:

```bash
SYSTEM_MEMCACHE_REPLICA_COUNT=$(oc get deployment system-memcache -o=jsonpath='{.spec.replicas}')
ZYNC_DATABASE_REPLICA_COUNT=$(oc get deployment zync-database -o=jsonpath='{.spec.replicas}')
APICAST_PRODUCTION_REPLICA_COUNT=$(oc get deployment apicast-production -o=jsonpath='{.spec.replicas}')
APICAST_STAGING_REPLICA_COUNT=$(oc get deployment apicast-staging -o=jsonpath='{.spec.replicas}')
BACKEND_CRON_REPLICA_COUNT=$(oc get deployment backend-cron -o=jsonpath='{.spec.replicas}')
BACKEND_LISTENER_REPLICA_COUNT=$(oc get deployment backend-listener -o=jsonpath='{.spec.replicas}')
BACKEND_WORKER_REPLICA_COUNT=$(oc get deployment backend-worker -o=jsonpath='{.spec.replicas}')
SYSTEM_APP_REPLICA_COUNT=$(oc get deployment system-app -o=jsonpath='{.spec.replicas}')
SYSTEM_SIDEKIQ_REPLICA_COUNT=$(oc get deployment system-sidekiq -o=jsonpath='{.spec.replicas}')
SYSTEM_SEARCHD_REPLICA_COUNT=$(oc get deployment system-searchd -o=jsonpath='{.spec.replicas}')
ZYNC_REPLICA_COUNT=$(oc get deployment zync -o=jsonpath='{.spec.replicas}')
ZYNC_QUE_REPLICA_COUNT=$(oc get deployment zync-que -o=jsonpath='{.spec.replicas}')
```

## 1. Escalar 3scale y el operador

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Dejar `system-postgresql` en 1.

## 2. Dump

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
```

## 3. Desplegar PostgreSQL 15

Copiar credenciales al namespace de BDD y aplicar el overlay (o el ApplicationSet):

```bash
DB_USER=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_USER}' | base64 -d)
DB_PASSWORD=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
oc create namespace "$DB_NAMESPACE" --dry-run=client -o yaml | oc apply -f -
oc create secret generic system-database \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  -n "$DB_NAMESPACE"
```

Desplegar **solo** PostgreSQL 15 (no el overlay `lab` completo: ese también crea Redis 7 y deja el dump de Redis embebido para más tarde):

```bash
oc apply -k kustomize/bases/postgresql -n "$DB_NAMESPACE"
```

En laboratorio AWS, si hace falta `gp3-csi`, parchear el PVC `postgresql-data-external`. GitOps de BDD: `oc apply -k gitops/external-db` (después del secret; incluye Redis — usar solo si el dump de Redis ya está hecho o se hará con Redis embebido otra vez arriba).

Esperar `1/1` en `system-postgresql-external`.

## 4. Restore

```bash
oc cp ./db_dump.backup "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')":/tmp -n "$DB_NAMESPACE"
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

El aviso `schema "public" already exists` es esperado. Verificar, por ejemplo:

```bash
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  psql -U postgres -d system -c 'SELECT org_name FROM accounts LIMIT 20;'
```

PostgreSQL 15 no da `CREATE` en el schema `public` al usuario de la app. Sin esto, el `system-app-pre` del salto a 2.16 falla con `permission denied for schema public`:

```bash
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

## 5. Secret y APIManager

```bash
oc get secret system-database -n "$THREESCALE_NAMESPACE" -o yaml > system-database-secret.yaml
DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@system-postgresql-service.${DB_NAMESPACE}.svc.cluster.local/system"
oc patch secret system-database -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"URL\":\"$DB_URL\"}}"
APIMANAGER_NAME=$(oc get apimanager -n "$THREESCALE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"system": {"database": true}}}}'
```

Eso desconecta el reconcile del operador sobre el PostgreSQL embebido y su PVC.

## 6. Subir 3scale y validar

Hay que **volver a subir Redis embebido** (`backend-redis` / `system-redis`) antes del runbook de Redis; si no, el `oc cp` del `dump.rdb` no tiene pods.

```bash
oc scale deployment backend-redis --replicas=1
oc scale deployment system-redis --replicas=1
oc scale deployment system-memcache --replicas=$SYSTEM_MEMCACHE_REPLICA_COUNT
oc scale deployment zync-database --replicas=$ZYNC_DATABASE_REPLICA_COUNT
oc scale deployment backend-cron --replicas=$BACKEND_CRON_REPLICA_COUNT
oc scale deployment backend-listener --replicas=$BACKEND_LISTENER_REPLICA_COUNT
oc scale deployment backend-worker --replicas=$BACKEND_WORKER_REPLICA_COUNT
oc scale deployment system-searchd --replicas=$SYSTEM_SEARCHD_REPLICA_COUNT
oc scale deployment zync --replicas=$ZYNC_REPLICA_COUNT
oc scale deployment zync-que --replicas=$ZYNC_QUE_REPLICA_COUNT
oc scale deployment system-app --replicas=$SYSTEM_APP_REPLICA_COUNT
oc scale deployment system-sidekiq --replicas=$SYSTEM_SIDEKIQ_REPLICA_COUNT
oc scale deployment apicast-staging --replicas=$APICAST_STAGING_REPLICA_COUNT
oc scale deployment apicast-production --replicas=$APICAST_PRODUCTION_REPLICA_COUNT
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=1
```

`system-postgresql` embebido debe quedar 0/0 (el operador ya no lo reconcilia). Validar portales y APIs.

Solo cuando los datos estén correctos:

```bash
oc delete deployment system-postgresql -n "$THREESCALE_NAMESPACE"
oc delete pvc postgresql-data -n "$THREESCALE_NAMESPACE"
oc delete service system-postgresql -n "$THREESCALE_NAMESPACE"
```

## Rollback

`externalComponents.system.database: false`, reaplicar `spec.system.database.postgresql: {}`, restaurar el secret desde `system-database-secret.yaml`, no borrar el PVC nuevo hasta confirmar el embebido.
