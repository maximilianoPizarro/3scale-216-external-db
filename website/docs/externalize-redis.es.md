# Externalizar Redis

Sigue el capítulo oficial *Redis 6 upgrade — On-cluster*. Hacen falta **dos** instancias (backend y system). Redis Cluster no está soportado. Runbook completo: `docs/runbooks/02-externalize-redis.md`.

Mismos `export` que [Externalizar PostgreSQL](externalize-postgresql.es.md). `REDIS_NAMESPACE=3scale-db`.

## 1. Escalar 3scale (dejar Redis embebido arriba)

Este paso asume que la externalización de PostgreSQL **ya volvió a subir Redis embebido**. Operador a 0. Escalar a 0 los componentes de 3scale **excepto** `backend-redis` y `system-redis`:

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Esperar a que Redis escriba a disco antes del dump.

## 2. Copiar `dump.rdb`

```bash
oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Desplegar Redis 7

```bash
oc apply -k kustomize/overlays/lab
```

El ConfigMap **restore** trae `save ""` y `appendonly no` (necesario para cargar el RDB). Esperar `backend-redis-external` y `system-redis-external` en `1/1`.

## 4. Restaurar RDB y reescribir AOF

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

Cuando estén Ready, ejecutar `redis-cli BGREWRITEAOF` en cada pod y esperar `aof_rewrite_in_progress = 0`.

## 5. Activar persistencia

```bash
oc apply -k kustomize/overlays/lab-persist
```

O cambiar en GitOps `redis-config.path` a `kustomize/bases/redis-config-persist`. Reiniciar los Deployments Redis y comprobar que el ConfigMap ya no tiene `save ""` y `appendonly` es `yes`.

## 6. Secrets y APIManager

Parchear los secrets `system-redis` y `backend-redis` con las URLs de los servicios externos, luego marcar `externalComponents` para ambas instancias Redis en el APIManager. Subir todos los componentes.

!!! tip "Capturar réplicas antes del scale-down"
    Si las variables de réplicas se capturaron **después** del scale-down, pueden ser `0`. Usar `--replicas=1` explícito (o el conteo original) al escalar.
