# Externalize Redis

This page is the same procedure as `docs/runbooks/02-externalize-redis.md`. On Git Bash, set `MSYS_NO_PATHCONV=1`. `docs/runbooks/02-bis-externalize-redis-windows.md` only adds that rule.

Use the same variables as [Externalize PostgreSQL](externalize-postgresql.md). Set `REDIS_NAMESPACE=3scale-db`.

`values-cutover.yaml` is the only file that sets `threescale.redis.allowRestore: true`. The chart refuses `configMode: restore` without that flag. Restore mode writes `save ""` and `appendonly no`. A restart does not rebuild data if `dump.rdb` was not loaded. Other value files must not fall into restore by default.

Redis has no password while it loads the RDB. Auth starts with `/values-216-external.yaml`, after the load and the smoke test. The NetworkPolicy from the cutover already limits port 6379 to namespaces `3scale` and `3scale-db`.

Do not `oc patch` the Redis Secrets or the APIManager. ExternalSecret writes the URLs when `externalComponents` becomes true.

## 1. Scale down, keep embedded Redis up

This step starts after PostgreSQL externalization scaled embedded Redis back up. Scale the operator and the other components to 0. Leave `backend-redis` and `system-redis` at their captured replica count.

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Confirm the operator Deployment name with `oc get deploy -n 3scale -o name`. On CSV 0.12 and 0.13 it is `threescale-operator-controller-manager-v2`.

## 2. SAVE, then copy `dump.rdb`

Record `DBSIZE` and `LASTSAVE`, run `SAVE`, and confirm `LASTSAVE` moved forward. Do not wait and hope the process wrote the file.

```bash
for dep in backend-redis system-redis; do
  pod=$(oc get pods -l deployment=$dep -o jsonpath='{.items[0].metadata.name}')
  echo "$dep before $(oc exec "$pod" -- redis-cli DBSIZE) lastsave $(oc exec "$pod" -- redis-cli LASTSAVE)"
  oc exec "$pod" -- redis-cli SAVE
  echo "$dep after-save $(oc exec "$pod" -- redis-cli LASTSAVE)"
done
oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
sha256sum ./backend-redis-dump.rdb ./system-redis-dump.rdb
wc -c ./backend-redis-dump.rdb ./system-redis-dump.rdb
chmod 600 ./backend-redis-dump.rdb ./system-redis-dump.rdb
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

## 3. Load the RDB

`/values-cutover.yaml` is already applied from the PostgreSQL cycle. Wait until `backend-redis-external` and `system-redis-external` are `1/1`.

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc exec -n "$REDIS_NAMESPACE" deploy/backend-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc exec -n "$REDIS_NAMESPACE" deploy/system-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

When the pods are Ready, compare `DBSIZE` with the numbers from step 2. Then `BGREWRITEAOF` in each pod and wait until `INFO persistence` shows `aof_rewrite_in_progress:0`. Re-read pod names after the restart.

## 4. Scale back, smoke test, then take a fresh dump

Restore replica counts from `$HOME/3scale-replicas-before-cutover.json`, except embedded `system-postgresql`, `backend-redis`, and `system-redis`, which stay at 0. Keep those PVCs.

On channel `threescale-2.15`, with the external databases:

- Admin Portal login returns success.
- Create an account and read it back.
- One APIcast call returns the expected status for a configured product.
- Sidekiq queues are not stuck (`oc exec` into `system-sidekiq` is not required if the pod is Ready and the portal job finishes).

Immediately before `/values-216-external.yaml`, take a new `pg_dump` and a new pair of `dump.rdb` files. Repeat the checksum and `DBSIZE` steps. Delete every dump when the upgrade is accepted.

## 5. Turn persistence and auth on

`/values-216-external.yaml` sets `configMode: persist`, Redis auth, and `externalComponents`. That is also the channel switch. Do it only after the fresh dump and the smoke test. See [Upgrade operator to 2.16](upgrade-216.md).

Confirm the ConfigMap no longer has `save ""` and `appendonly` is `yes`. A restart in restore mode does not reconstruct keys that were never loaded.
