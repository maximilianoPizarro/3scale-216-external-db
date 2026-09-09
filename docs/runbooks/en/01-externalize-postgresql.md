# Externalize PostgreSQL (10 → 15) in-cluster

Follow the *PostgreSQL 10 upgrade - On-cluster* chapter of the official 2.16 guide. Operational summary using manifests from this repo. Commands for **Linux/macOS**. On Git Bash (Windows): [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md).

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
```

With the `lab-operator` overlay, operator and APIManager live in `3scale`. Save replica counts before scaling to 0:

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

## 1. Scale 3scale and the operator

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Leave `system-postgresql` at 1.

## 2. Dump

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
```

## 3. Deploy PostgreSQL 15

Copy credentials to the database namespace and apply the overlay (or the ApplicationSet):

```bash
DB_USER=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_USER}' | base64 -d)
DB_PASSWORD=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
oc create namespace "$DB_NAMESPACE" --dry-run=client -o yaml | oc apply -f -
oc create secret generic system-database \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  -n "$DB_NAMESPACE"
```

Deploy **only** PostgreSQL 15 (not the full `lab` overlay: that also creates Redis 7 and leaves the Redis dump for later):

```bash
oc apply -k kustomize/bases/postgresql -n "$DB_NAMESPACE"
```

On AWS lab, if `gp3-csi` is required, patch PVC `postgresql-data-external`. Database GitOps: `oc apply -k gitops/external-db` (after the secret; includes Redis — use only if the Redis dump is already done or embedded Redis will be brought up again above).

Wait for `1/1` on `system-postgresql-external`.

## 4. Restore

```bash
oc cp ./db_dump.backup "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')":/tmp -n "$DB_NAMESPACE"
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

The warning `schema "public" already exists` is expected. Verify, for example:

```bash
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  psql -U postgres -d system -c 'SELECT org_name FROM accounts LIMIT 20;'
```

PostgreSQL 15 does not grant `CREATE` on schema `public` to the application user. Without this, the 2.16 jump `system-app-pre` fails with `permission denied for schema public`:

```bash
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

## 5. Secret and APIManager

```bash
oc get secret system-database -n "$THREESCALE_NAMESPACE" -o yaml > system-database-secret.yaml
DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@system-postgresql-service.${DB_NAMESPACE}.svc.cluster.local/system"
oc patch secret system-database -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"URL\":\"$DB_URL\"}}"
APIMANAGER_NAME=$(oc get apimanager -n "$THREESCALE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"system": {"database": true}}}}'
```

That disconnects operator reconcile over embedded PostgreSQL and its PVC.

## 6. Scale up 3scale and validate

You must **bring embedded Redis back up** (`backend-redis` / `system-redis`) before the Redis runbook; otherwise the `oc cp` of `dump.rdb` has no pods.

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

Embedded `system-postgresql` must stay 0/0 (the operator no longer reconciles it). Validate portals and APIs.

Only when data is correct:

```bash
oc delete deployment system-postgresql -n "$THREESCALE_NAMESPACE"
oc delete pvc postgresql-data -n "$THREESCALE_NAMESPACE"
oc delete service system-postgresql -n "$THREESCALE_NAMESPACE"
```

## Rollback

`externalComponents.system.database: false`, reapply `spec.system.database.postgresql: {}`, restore the secret from `system-database-secret.yaml`, do not delete the new PVC until embedded is confirmed.
