# Upgrade 3scale operator 2.15 → 2.16

Prerequisite: system PostgreSQL ≥ 15.0 and Redis ≥ 7.2 **already externalized** (`externalComponents` true). If versions do not meet requirements, operator 2.16 installs but **does not** complete the instance upgrade.

## Preflight

On self-managed database pods:

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- psql --version
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

## OLM channel

Change the 3scale operator Subscription to channel `threescale-2.16`. Approve InstallPlans if approval is manual.

Wait for pods Ready. Expected APIManager annotations:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

APIcast operator-based, if applicable, has its own 2.16 channel (migration guide chapter 2).

## If `system-app-pre` fails with `permission denied for schema public`

PostgreSQL 15 revokes `CREATE` on `public` except for the schema owner. After a restore done as `postgres`, user `system` cannot migrate. Full command in [01-externalize-postgresql.md](01-externalize-postgresql.md) (GRANT section). Delete Job `system-app-pre` and let the operator recreate it.

## If version preflight fails

Raise PostgreSQL/Redis to minimums and let operator 2.16 retry (every ~10 minutes) or rescale the operator controller.
