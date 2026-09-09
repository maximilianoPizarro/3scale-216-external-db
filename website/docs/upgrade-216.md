# Upgrade operator to 2.16

!!! warning "Preflight requirement"
    Externalize system PostgreSQL ≥ 15.0 and Redis ≥ 7.2 first (`externalComponents` set).
    If versions do not meet this, the 3scale operator 2.16 installs but the instance upgrade does not complete.

## Run preflight checks

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- psql --version
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

## Switch the OLM channel

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

PostgreSQL 15 revokes `CREATE` on schema `public` except for the schema owner. After a restore done as `postgres`, user `system` cannot run migrations.

!!! warning "PostgreSQL 15 grant required"
    Run the full `GRANT USAGE, CREATE ON SCHEMA public` command during externalization — [Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public). Delete the `system-app-pre` Job and let the 3scale operator recreate it.

## If version preflight fails

Upgrade PostgreSQL and Redis to the minimum versions. Let the 3scale operator 2.16 retry (approximately every 10 minutes) or rescale the operator controller.
