# Upgrade operator to 2.16

**Prerequisite:** system PostgreSQL ≥ 15.0 and Redis ≥ 7.2 already externalized (`externalComponents` set). If versions do not meet preflight, the 2.16 operator installs but **does not complete** the instance upgrade.

## Preflight

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- psql --version
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

## OLM channel

Change the 3scale operator Subscription to channel `threescale-2.16`. Approve InstallPlans if approval is manual.

```bash
oc apply -k kustomize/overlays/operator-216
```

Wait for pods to be ready. Expected APIManager annotations:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

APIcast operator-based deployments, if applicable, have their own 2.16 channel (migration guide chapter 2).

## If `system-app-pre` fails: `permission denied for schema public`

PostgreSQL 15 revokes `CREATE` on schema `public` except for the schema owner. After a restore done as `postgres`, user `system` cannot run migrations:

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

Delete the `system-app-pre` Job and let the operator recreate it. This grant should already be applied during [Externalize PostgreSQL](externalize-postgresql.md) — apply again if it was missed.

## If version preflight fails

Upgrade PostgreSQL/Redis to the minimum versions and let the 2.16 operator retry (approximately every 10 minutes) or rescale the operator controller.
