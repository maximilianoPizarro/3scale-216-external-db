# Externalizar Redis (6 → 7) in-cluster

Sigue el capítulo *Redis 6 upgrade - On-cluster*. Hacen falta **dos** instancias (backend y system). Redis Cluster no está soportado. Comandos para **Linux/macOS**. En Git Bash (Windows): [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md).

Mismos `export` que [01-externalize-postgresql.md](01-externalize-postgresql.md) (`THREESCALE_NAMESPACE`, `OPERATOR_NAMESPACE`). `REDIS_NAMESPACE=3scale-db`.

## 1. Escalar 3scale (dejar Redis embebido arriba)

Este capítulo asume que el de PostgreSQL **ya subió** `backend-redis` y `system-redis` otra vez. Operador a 0. Escalar a 0 los componentes de 3scale **excepto** esos dos Redis:

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Esperar a que Redis escriba a disco antes del dump.

## 2. Copiar dump.rdb

```bash
oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
```

Luego:

```bash
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Desplegar Redis 7

```bash
oc apply -k kustomize/overlays/lab
# o GitOps de BDD (tras el secret system-database en 3scale-db):
# oc apply -k gitops/external-db
```

El ConfigMap **restore** trae `save ""` y `appendonly no` (necesario para cargar el RDB). Si PostgreSQL 15 ya existía, el overlay lab es idempotente sobre ese Deployment.

Esperar `1/1` en `backend-redis-external` y `system-redis-external`.

## 4. Restaurar RDB y AOF

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

Cuando estén Ready:

```bash
oc rsh -n "$REDIS_NAMESPACE" "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')" bash -c 'redis-cli BGREWRITEAOF'
oc rsh -n "$REDIS_NAMESPACE" "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')" bash -c 'redis-cli BGREWRITEAOF'
```

Esperar `aof_rewrite_in_progress = 0`.

## 5. Activar persistencia

GitOps: en el ApplicationSet, `redis-config.path` → `kustomize/bases/redis-config-persist`.

Sin GitOps:

```bash
oc apply -k kustomize/overlays/lab-persist
```

Reiniciar los Deployments Redis. Comprobar que el ConfigMap ya no tiene `save ""` y que `appendonly` es `yes`.

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

Validar portales y tráfico. Solo entonces eliminar Deployments/PVC/Service `backend-redis` y `system-redis` del namespace de 3scale.

## Rollback

`externalComponents.*.redis: false`, restaurar secrets, dejar que el operador 2.15 vuelva a gestionar Redis 6. No borrar los PVC nuevos hasta confirmar.
