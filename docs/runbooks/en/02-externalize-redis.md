# Externalize Redis (6 → 7) in-cluster

Same procedure as `website/docs/externalize-redis.md`. On Git Bash: [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md) only adds `MSYS_NO_PATHCONV=1`.

`values-cutover.yaml` is the only file with `allowRestore: true`. The chart refuses `configMode: restore` without that flag. That mode sets `save ""` and `appendonly no`: a restart does not rebuild data if the RDB was not loaded. Redis stays without auth only while loading. Auth and `persist` start with `/values-215-external.yaml`, before returning traffic. Channel `threescale-2.16` is the next file.

## 1. Scale to 0 and leave embedded Redis up

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Confirm the operator Deployment name. On 0.12 and 0.13 it is `threescale-operator-controller-manager-v2`.

## 2. SAVE and copy `dump.rdb`

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

`LASTSAVE` must advance. Do not wait for Redis to write on its own.

## 3. Load the RDB

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc exec -n "$REDIS_NAMESPACE" deploy/backend-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc exec -n "$REDIS_NAMESPACE" deploy/system-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

Compare `DBSIZE` with step 2. Then `BGREWRITEAOF` and wait for `aof_rewrite_in_progress:0`. Redis is still in restore mode here (`save ""`, `appendonly no`).

## 4. Persistence and Secrets before returning traffic

Set `extraValueFiles` to `/values-215-external.yaml`. That file sets `configMode: persist`, Redis auth, and `externalComponents`, and keeps channel `threescale-2.15`. ExternalSecret rewrites the URLs. Do not patch Secrets or the APIManager by hand. Argo overwrites that change.

The auth change recreates the Deployment. Confirm `appendonly yes` and the same `DBSIZE` on the new pod:

```bash
oc -n 3scale-db get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-cli -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE
oc exec -n 3scale-db deploy/system-redis-external -- redis-cli -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE
```

## 5. Verification on 2.15 and fresh dump

Restore replicas from `$HOME/3scale-replicas-before-cutover.json`. The operator does not raise `system-app` or `system-sidekiq` from 0; scale those two from the JSON. Leave embedded PostgreSQL and Redis at 0 and keep their PVCs. `zync-database` returns to 1.

On 2.15, against the restored databases:

- Admin Portal login.
- Developer Portal.
- Create and read back an account.
- One APIcast call.
- Analytics chart with historical traffic (confirms the `backend-redis` RDB; a new call only proves write).
- Account, service, and application counts against the pre-window snapshot.
- Sidekiq queues not stuck.

Immediately before `/values-216-external.yaml`, repeat `pg_dump` and both `dump.rdb` files with checksums and `DBSIZE`.

## 6. Channel 2.16

`/values-216-external.yaml` only switches the channel to `threescale-2.16`. 2.15 already reads the databases. See [03-upgrade-215-to-216.md](03-upgrade-215-to-216.md).

## Rollback

Until `system-app-pre` on 2.16, scale embedded Redis back up. Do not delete its PVCs. The official guide deletes them at the end of the chapter; this procedure does not. After that job, restore the fresh dump.
