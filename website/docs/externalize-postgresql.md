# Externalize PostgreSQL

Follow the official *PostgreSQL 10 upgrade — On-cluster* chapter. This page summarizes the procedure with manifests from this repository. Full runbook: `docs/runbooks/01-externalize-postgresql.md` (Git Bash: `docs/runbooks/01-bis-externalize-postgresql-windows.md`).

## Variables

```bash
export THREESCALE_NAMESPACE=3scale
export OPERATOR_NAMESPACE=3scale
export DB_NAMESPACE=3scale-db
oc project "$THREESCALE_NAMESPACE"
```

Capture replica counts **before** you scale to 0 (see the runbook for the full list).

## 1. Scale down 3scale and the 3scale operator

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,backend-redis,system-app,system-redis,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Leave `system-postgresql` at 1 replica.

## 2. Dump

```bash
POSTGRES_POD=$(oc get pods -l deployment=system-postgresql -o jsonpath='{.items[0].metadata.name}')
oc exec "$POSTGRES_POD" -- pg_dump -U system -d system -F c -b -v -f /tmp/db_dump.backup
oc cp "$POSTGRES_POD":/tmp/db_dump.backup ./db_dump.backup
```

## 3. Deploy PostgreSQL 15

```bash
DB_USER=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_USER}' | base64 -d)
DB_PASSWORD=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
oc create namespace "$DB_NAMESPACE" --dry-run=client -o yaml | oc apply -f -
oc create secret generic system-database \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  -n "$DB_NAMESPACE"
oc apply -k kustomize/bases/postgresql -n "$DB_NAMESPACE"
```

Confirm `DB_USER` and `DB_PASSWORD` are not empty before the pod initializes the PVC.

Deploy **only** PostgreSQL 15 first. Do not apply the full `lab` overlay yet. That overlay also creates Redis 7. Wait for `system-postgresql-external` at `1/1`.

## 4. Restore

```bash
oc cp ./db_dump.backup "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')":/tmp -n "$DB_NAMESPACE"
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  bash -c 'pg_restore -v -h localhost -U postgres -d system /tmp/db_dump.backup'
```

The warning `schema "public" already exists` is expected.

### Grant CREATE on schema `public`

PostgreSQL 15 does not grant `CREATE` on schema `public` to the application user. Without this step, the `system-app-pre` job fails on the 2.16 upgrade with `permission denied for schema public`.

```bash
oc rsh -n "$DB_NAMESPACE" "$(oc get pods -n "$DB_NAMESPACE" -l deployment=system-postgresql-external -o jsonpath='{.items[0].metadata.name}')" \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

## 5. Patch the secret and the APIManager

```bash
oc get secret system-database -n "$THREESCALE_NAMESPACE" -o yaml > system-database-secret.yaml
DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@system-postgresql-service.${DB_NAMESPACE}.svc.cluster.local/system"
oc patch secret system-database -n "$THREESCALE_NAMESPACE" -p "{\"stringData\":{\"URL\":\"$DB_URL\"}}"
APIMANAGER_NAME=$(oc get apimanager -n "$THREESCALE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
oc patch apimanager "$APIMANAGER_NAME" -n "$THREESCALE_NAMESPACE" --type=merge \
  -p '{"spec": {"externalComponents": {"system": {"database": true}}}}'
```

This disconnects the 3scale operator from the embedded PostgreSQL Deployment and PVC.

## 6. Scale up and validate

Scale **embedded Redis** (`backend-redis`, `system-redis`) back up before the Redis runbook. Restore the other replica counts. Then validate portals and APIs.

After you confirm the data, delete the embedded PostgreSQL Deployment, PVC, and Service.

!!! danger "Do not commit secrets or dumps"
    Never commit `*-secret.yaml`, `*.backup`, or `*.rdb` files.
