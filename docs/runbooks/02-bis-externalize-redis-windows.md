# Externalizar Redis (6 → 7) in-cluster — Windows (Git Bash)

Misma secuencia que [02-externalize-redis.md](02-externalize-redis.md). Esta variante es para **Git Bash (MINGW64)**, no PowerShell.

Git Bash reescribe rutas que empiezan por `/` (`/var/lib/redis/...`, `/tmp`). `oc cp pod:/var/lib/...` acaba leyendo un path Windows y el RDB no se copia (o queda vacío). `tar: Removing leading '/' from member names` **no** es error por sí solo; el archivo local tiene que tener tamaño > 0 y cabecera `REDIS`.

Aquí no se usa `oc cp` con path Unix. Se copia con `oc exec` + `bash -c` (la ruta vive dentro del pod) y `MSYS_NO_PATHCONV=1`.

Si ya bajaste 3scale (paso 1) y Redis embebido sigue en 1, arrancá en el paso 2.

## Variables

```bash
export MSYS_NO_PATHCONV=1
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export REDIS_NAMESPACE="${REDIS_NAMESPACE:-3scale-db}"
oc project "$THREESCALE_NAMESPACE"
```

Guardar réplicas **antes** de escalar a 0 (en esta misma shell):

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

Si ya escalaste y `spec.replicas` es 0, al subir usá `1` (o el valor real previo).

## 1. Escalar 3scale (dejar Redis embebido arriba)

Operador a 0. Escalar a 0 los componentes **excepto** `backend-redis` y `system-redis`.

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

No tocar `system-postgresql` (ya no debería existir) ni los dos Redis.

## 2. SAVE y copiar dump.rdb

```bash
BACKEND_POD=$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')
SYSTEM_POD=$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')

oc exec "$BACKEND_POD" -- bash -c 'redis-cli SAVE'
oc exec "$SYSTEM_POD" -- bash -c 'redis-cli SAVE'

oc exec "$BACKEND_POD" -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./backend-redis-dump.rdb
oc exec "$SYSTEM_POD" -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./system-redis-dump.rdb

ls -lh ./backend-redis-dump.rdb ./system-redis-dump.rdb
```

Los dos archivos tienen que pesar más que 0. Cabecera `REDIS`:

```bash
head -c 5 ./backend-redis-dump.rdb; echo
head -c 5 ./system-redis-dump.rdb; echo
```

Si ves `REDIS`, el dump está bien. Si el archivo está vacío o es un HTML de error, no sigas.

Luego:

```bash
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Desplegar Redis 7

```bash
oc apply -k kustomize/overlays/lab
```

El ConfigMap **restore** trae `save ""` y `appendonly no` (necesario para cargar el RDB). El overlay es idempotente sobre PostgreSQL 15.

Esperar `1/1` en `backend-redis-external` y `system-redis-external`:

```bash
oc -n "$REDIS_NAMESPACE" rollout status deployment/backend-redis-external
oc -n "$REDIS_NAMESPACE" rollout status deployment/system-redis-external
```

## 4. Restaurar RDB y AOF

```bash
B_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')
S_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')

oc exec -i -n "$REDIS_NAMESPACE" "$B_EXT" -- bash -c 'cat > /var/lib/redis/data/dump.rdb' < ./backend-redis-dump.rdb
oc exec -i -n "$REDIS_NAMESPACE" "$S_EXT" -- bash -c 'cat > /var/lib/redis/data/dump.rdb' < ./system-redis-dump.rdb

oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
oc -n "$REDIS_NAMESPACE" rollout status deployment/backend-redis-external
oc -n "$REDIS_NAMESPACE" rollout status deployment/system-redis-external
```

Volver a leer los nombres de pod (cambiaron con el restart) y reescribir AOF. Si `B_EXT`/`S_EXT` salen vacíos, `$REDIS_NAMESPACE` no está exportada (Git Bash a veces la pierde) y `oc` busca en `3scale` en lugar de `3scale-db`:

```bash
export REDIS_NAMESPACE=3scale-db
B_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')
S_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')
echo "B_EXT=$B_EXT"
echo "S_EXT=$S_EXT"
oc exec -n "$REDIS_NAMESPACE" "$B_EXT" -- bash -c 'redis-cli BGREWRITEAOF'
oc exec -n "$REDIS_NAMESPACE" "$S_EXT" -- bash -c 'redis-cli BGREWRITEAOF'
```

Esperar `aof_rewrite_in_progress:0`:

```bash
oc exec -n "$REDIS_NAMESPACE" "$B_EXT" -- bash -c 'redis-cli INFO persistence' | grep aof_rewrite_in_progress
oc exec -n "$REDIS_NAMESPACE" "$S_EXT" -- bash -c 'redis-cli INFO persistence' | grep aof_rewrite_in_progress
```

## 5. Activar persistencia

```bash
oc apply -k kustomize/overlays/lab-persist
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
oc -n "$REDIS_NAMESPACE" rollout status deployment/backend-redis-external
oc -n "$REDIS_NAMESPACE" rollout status deployment/system-redis-external
oc -n "$REDIS_NAMESPACE" get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
```

El ConfigMap no debe tener `save ""`; `appendonly` debe ser `yes`.

## 6. Secrets y APIManager

```bash
oc get secret system-redis -n "$THREESCALE_NAMESPACE" -o yaml > system-redis-secret.yaml
oc get secret backend-redis -n "$THREESCALE_NAMESPACE" -o yaml > backend-redis-secret.yaml
BACKEND_REDIS_URL="redis://backend-redis-service.${REDIS_NAMESPACE}.svc.cluster.local:6379"
oc patch secret backend-redis -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"REDIS_STORAGE_URL\":\"$BACKEND_REDIS_URL/0\"}}"
oc patch secret backend-redis -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"REDIS_QUEUES_URL\":\"$BACKEND_REDIS_URL/1\"}}"
SYSTEM_REDIS_URL="redis://system-redis-service.${REDIS_NAMESPACE}.svc.cluster.local:6379/1"
oc patch secret system-redis -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"URL\":\"$SYSTEM_REDIS_URL\"}}"
APIMANAGER_NAME=$(oc get apimanager -n "$THREESCALE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"system": {"redis": true}}}}'
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"backend": {"redis": true}}}}'
```

## 7. Subir 3scale y borrar embebidos

```bash
oc scale deployment system-memcache --replicas=1
oc scale deployment zync-database --replicas=1
oc scale deployment backend-cron --replicas=1
oc scale deployment backend-listener --replicas=1
oc scale deployment backend-worker --replicas=1
oc scale deployment system-searchd --replicas=1
oc scale deployment zync --replicas=1
oc scale deployment zync-que --replicas=1
oc scale deployment system-app --replicas=1
oc scale deployment system-sidekiq --replicas=1
oc scale deployment apicast-staging --replicas=1
oc scale deployment apicast-production --replicas=1
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=1
```

Incluir **system-app** a 1; si solo se sube el operador, el hook `system-app-pre` puede fallar por `backend-listener` caído y `system-app` quedarse en 0/0.

Si las variables de réplica se capturaron **después** de bajar a 0, `${VAR:-1}` sigue valiendo 0 (el `:-` solo aplica si está vacía). Usar `--replicas=1` (o el valor real previo). No subir `backend-redis` ni `system-redis` embebidos.

Solo cuando esté bien:

```bash
oc delete deployment backend-redis system-redis -n "$THREESCALE_NAMESPACE"
oc delete pvc backend-redis-storage system-redis-storage -n "$THREESCALE_NAMESPACE"
oc delete service backend-redis system-redis -n "$THREESCALE_NAMESPACE"
```

## Rollback

`externalComponents.system.redis` y `externalComponents.backend.redis` a `false`, restaurar secrets, dejar que el operador 2.15 vuelva a gestionar Redis 6. No borrar los PVC nuevos hasta confirmar.
