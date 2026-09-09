# Externalize Redis (6 → 7) in-cluster

Follow the *Redis 6 upgrade - On-cluster* chapter. You need **two** instances (backend and system). Redis Cluster is not supported. Commands for **Linux/macOS**. On Git Bash (Windows): [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md).

Same `export` as [01-externalize-postgresql.md](01-externalize-postgresql.md) (`THREESCALE_NAMESPACE`, `OPERATOR_NAMESPACE`). `REDIS_NAMESPACE=3scale-db`.

## 1. Scale 3scale (leave embedded Redis up)

This chapter assumes the PostgreSQL runbook **already scaled** `backend-redis` and `system-redis` back up. Operator to 0. Scale 3scale components to 0 **except** those two Redis instances:

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Wait for Redis to flush to disk before the dump.

## 2. Copy dump.rdb

```bash
oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
```

Then:

```bash
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Deploy Redis 7

```bash
oc apply -k kustomize/overlays/lab
# or database GitOps (after system-database secret in 3scale-db):
# oc apply -k gitops/external-db
```

The **restore** ConfigMap sets `save ""` and `appendonly no` (required to load the RDB). If PostgreSQL 15 already exists, the lab overlay is idempotent over that Deployment.

Wait for `1/1` on `backend-redis-external` and `system-redis-external`.

## 4. Restore RDB and AOF

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

When Ready:

```bash
oc rsh -n "$REDIS_NAMESPACE" "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')" bash -c 'redis-cli BGREWRITEAOF'
oc rsh -n "$REDIS_NAMESPACE" "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')" bash -c 'redis-cli BGREWRITEAOF'
```

Wait for `aof_rewrite_in_progress = 0`.

## 5. Enable persistence

GitOps: in the ApplicationSet, set `redis-config.path` → `kustomize/bases/redis-config-persist`.

Without GitOps:

```bash
oc apply -k kustomize/overlays/lab-persist
```

Restart Redis Deployments. Confirm the ConfigMap no longer has `save ""` and `appendonly` is `yes`.

## 6. Secrets and APIManager

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

## 7. Scale up 3scale and delete embedded

Validate portals and traffic. Only then delete Deployments/PVC/Service `backend-redis` and `system-redis` in the 3scale namespace.

## Rollback

`externalComponents.*.redis: false`, restore secrets, let operator 2.15 manage Redis 6 again. Do not delete the new PVCs until confirmed.
