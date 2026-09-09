# Externalize Redis

Follow the official *Redis 6 upgrade — On-cluster* chapter. You need two instances (backend and system). Redis Cluster is not supported. Full Linux runbook: `docs/runbooks/02-externalize-redis.md`.

Use the same `export` variables as [Externalize PostgreSQL](externalize-postgresql.md). Set `REDIS_NAMESPACE=3scale-db`.

!!! tip "Windows / Git Bash"
    Read [Windows / Git Bash](windows.md) first. Do not use `oc cp` with Unix paths. Copy with `oc exec` + `bash -c` so the path stays inside the pod.

## 1. Scale down 3scale (keep embedded Redis up)

This step assumes PostgreSQL externalization **already scaled embedded Redis back up**. Scale the 3scale operator and 3scale components to 0 **except** `backend-redis` and `system-redis`:

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Wait for Redis to flush data to disk before the dump.

## 2. Copy `dump.rdb`

=== "Linux"

    ```bash
    oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
    oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
    oc scale deployment/system-redis --replicas=0
    oc scale deployment/backend-redis --replicas=0
    ```

=== "Windows / Git Bash"

    ```bash
    export MSYS_NO_PATHCONV=1
    BACKEND_POD=$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')
    SYSTEM_POD=$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')

    oc exec "$BACKEND_POD" -- bash -c 'redis-cli SAVE'
    oc exec "$SYSTEM_POD" -- bash -c 'redis-cli SAVE'

    oc exec "$BACKEND_POD" -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./backend-redis-dump.rdb
    oc exec "$SYSTEM_POD" -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./system-redis-dump.rdb

    ls -lh ./backend-redis-dump.rdb ./system-redis-dump.rdb
    head -c 5 ./backend-redis-dump.rdb; echo
    head -c 5 ./system-redis-dump.rdb; echo
    ```

    Both files must have size greater than 0 and start with `REDIS`. Then:

    ```bash
    oc scale deployment/system-redis --replicas=0
    oc scale deployment/backend-redis --replicas=0
    ```

## 3. Deploy Redis 7

```bash
oc apply -k kustomize/overlays/lab
```

The **restore** ConfigMap sets `save ""` and `appendonly no` (required to load the RDB). Wait for `backend-redis-external` and `system-redis-external` at `1/1`.

## 4. Restore RDB and rewrite AOF

=== "Linux"

    ```bash
    export REDIS_NAMESPACE=3scale-db
    oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
    oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
    oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
    oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
    ```

=== "Windows / Git Bash"

    ```bash
    export MSYS_NO_PATHCONV=1
    export REDIS_NAMESPACE=3scale-db
    B_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')
    S_EXT=$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')

    oc exec -i -n "$REDIS_NAMESPACE" "$B_EXT" -- bash -c 'cat > /var/lib/redis/data/dump.rdb' < ./backend-redis-dump.rdb
    oc exec -i -n "$REDIS_NAMESPACE" "$S_EXT" -- bash -c 'cat > /var/lib/redis/data/dump.rdb' < ./system-redis-dump.rdb

    oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
    oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
    ```

When the pods are Ready, run `redis-cli BGREWRITEAOF` in each pod and wait for `aof_rewrite_in_progress = 0`. Re-read pod names after the restart.

## 5. Enable persistence

```bash
oc apply -k kustomize/overlays/lab-persist
```

Or switch GitOps `redis-config.path` to `kustomize/bases/redis-config-persist`. Restart the Redis Deployments. Confirm the ConfigMap no longer has `save ""` and `appendonly` is `yes`.

## 6. Patch secrets and the APIManager

Patch `system-redis` and `backend-redis` secrets with the external service URLs. Then set `externalComponents` for both Redis instances on the APIManager. Scale all components back up.

!!! tip "Capture replicas before scale-down"
    If you captured replica variables **after** scale-down, they may be `0`. Use explicit `--replicas=1` (or the original count) when you scale up.
