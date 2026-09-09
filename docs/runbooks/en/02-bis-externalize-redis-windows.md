# Externalize Redis (6 → 7) in-cluster — Windows (Git Bash)

Same sequence as [02-externalize-redis.md](02-externalize-redis.md). This variant is for **Git Bash (MINGW64)**, not PowerShell.

Git Bash rewrites paths that start with `/` (`/var/lib/redis/...`, `/tmp`). `oc cp pod:/var/lib/...` ends up reading a Windows path and the RDB is not copied (or stays empty). `tar: Removing leading '/' from member names` is **not** an error by itself; the local file must be size > 0 and have header `REDIS`.

Here `oc cp` with Unix paths is not used. Copy with `oc exec` + `bash -c` (the path lives inside the pod) and `MSYS_NO_PATHCONV=1`.

If you already scaled 3scale down (step 1) and embedded Redis is still at 1, start at step 2.

## Variables

```bash
export MSYS_NO_PATHCONV=1
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export REDIS_NAMESPACE="${REDIS_NAMESPACE:-3scale-db}"
oc project "$THREESCALE_NAMESPACE"
```

Save replica counts **before** scaling to 0 (in this same shell):

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

If you already scaled and `spec.replicas` is 0, use `1` (or the previous real value) when scaling back up.

## 1. Scale 3scale (leave embedded Redis up)

Operator to 0. Scale components to 0 **except** `backend-redis` and `system-redis`.

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Do not touch `system-postgresql` (should no longer exist) or the two Redis instances.

## 2. SAVE and copy dump.rdb

```bash
BACKEND_POD=$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')
SYSTEM_POD=$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')

oc exec "$BACKEND_POD" -- bash -c 'redis-cli SAVE'
oc exec "$SYSTEM_POD" -- bash -c 'redis-cli SAVE'

oc exec "$BACKEND_POD" -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./backend-redis-dump.rdb
oc exec "$SYSTEM_POD" -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./system-redis-dump.rdb

ls -lh ./backend-redis-dump.rdb ./system-redis-dump.rdb
```

Both files must be larger than 0. Header `REDIS`:

```bash
head -c 5 ./backend-redis-dump.rdb; echo
head -c 5 ./system-redis-dump.rdb; echo
```

If you see `REDIS`, the dump is good. If the file is empty or error HTML, do not continue.

Then:

```bash
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Deploy Redis 7

```bash
oc apply -k kustomize/overlays/lab
```

The **restore** ConfigMap sets `save ""` and `appendonly no` (required to load the RDB). The overlay is idempotent over PostgreSQL 15.

Wait for `1/1` on `backend-redis-external` and `system-redis-external`:

```bash
oc -n "$REDIS_NAMESPACE" rollout status deployment/backend-redis-external
oc -n "$REDIS_NAMESPACE" rollout status deployment/system-redis-external
```

## 4. Restore RDB and AOF

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

Re-read pod names (they changed after restart) and rewrite AOF. If `B_EXT`/`S_EXT` are empty, `$REDIS_NAMESPACE` is not exported (Git Bash sometimes drops it) and `oc` looks in `3scale` instead of `3scale-db`:

```bash
export REDIS_NAMESPACE=3scale-db
B_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')
S_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')
echo "B_EXT=$B_EXT"
echo "S_EXT=$S_EXT"
oc exec -n "$REDIS_NAMESPACE" "$B_EXT" -- bash -c 'redis-cli BGREWRITEAOF'
oc exec -n "$REDIS_NAMESPACE" "$S_EXT" -- bash -c 'redis-cli BGREWRITEAOF'
```

Wait for `aof_rewrite_in_progress:0`:

```bash
oc exec -n "$REDIS_NAMESPACE" "$B_EXT" -- bash -c 'redis-cli INFO persistence' | grep aof_rewrite_in_progress
oc exec -n "$REDIS_NAMESPACE" "$S_EXT" -- bash -c 'redis-cli INFO persistence' | grep aof_rewrite_in_progress
```

## 5. Enable persistence

```bash
oc apply -k kustomize/overlays/lab-persist
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
oc -n "$REDIS_NAMESPACE" rollout status deployment/backend-redis-external
oc -n "$REDIS_NAMESPACE" rollout status deployment/system-redis-external
oc -n "$REDIS_NAMESPACE" get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
```

The ConfigMap must not have `save ""`; `appendonly` must be `yes`.

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

Include **system-app** at 1; if only the operator is scaled up, the `system-app-pre` hook can fail with `backend-listener` down and `system-app` stays 0/0.

If replica variables were captured **after** scaling to 0, `${VAR:-1}` is still 0 (`:-` only applies when empty). Use `--replicas=1` (or the previous real value). Do not scale up embedded `backend-redis` or `system-redis`.

Only when everything is healthy:

```bash
oc delete deployment backend-redis system-redis -n "$THREESCALE_NAMESPACE"
oc delete pvc backend-redis-storage system-redis-storage -n "$THREESCALE_NAMESPACE"
oc delete service backend-redis system-redis -n "$THREESCALE_NAMESPACE"
```

## Rollback

`externalComponents.system.redis` and `externalComponents.backend.redis` to `false`, restore secrets, let operator 2.15 manage Redis 6 again. Do not delete the new PVCs until confirmed.
