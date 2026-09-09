# Externalize Redis

Follow the official *Redis 6 upgrade — On-cluster* chapter. Two instances are required (backend and system). Redis Cluster is not supported. Full runbook: `docs/runbooks/02-externalize-redis.md`.

Use the same `export` variables as [Externalize PostgreSQL](externalize-postgresql.md). Set `REDIS_NAMESPACE=3scale-db`.

## 1. Scale down 3scale (keep embedded Redis up)

This step assumes PostgreSQL externalization **already scaled embedded Redis back up**. Scale the operator and 3scale components to 0 **except** `backend-redis` and `system-redis`:

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Wait for Redis to flush data to disk before the dump.

## 2. Copy `dump.rdb`

```bash
oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Deploy Redis 7

```bash
oc apply -k kustomize/overlays/lab
```

The **restore** ConfigMap sets `save ""` and `appendonly no` (required to load the RDB). Wait for `backend-redis-external` and `system-redis-external` at `1/1`.

## 4. Restore RDB and rewrite AOF

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

When Ready, run `redis-cli BGREWRITEAOF` in each pod and wait for `aof_rewrite_in_progress = 0`.

## 5. Enable persistence

```bash
oc apply -k kustomize/overlays/lab-persist
```

Or switch GitOps `redis-config.path` to `kustomize/bases/redis-config-persist`. Restart Redis Deployments and confirm the ConfigMap no longer has `save ""` and `appendonly` is `yes`.

## 6. Secrets and APIManager

Patch `system-redis` and `backend-redis` secrets with the external service URLs, then set `externalComponents` for both Redis instances on the APIManager. Scale all components back up.

!!! tip "Capture replicas before scale-down"
    If replica variables were captured **after** scale-down, they may be `0`. Use explicit `--replicas=1` (or the original count) when scaling up.
