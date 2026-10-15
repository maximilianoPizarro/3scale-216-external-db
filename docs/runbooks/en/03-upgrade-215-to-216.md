# Upgrade 3scale operator 2.15 → 2.16

Prerequisite: system PostgreSQL ≥ 15.0 and Redis ≥ 7.2 **already externalized** (`externalComponents` true). If versions do not meet requirements, operator 2.16 installs but **does not** complete the instance upgrade.

## Preflight

Server version, before the channel switch. `psql --version` is the client.

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'SELECT version();'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

Take a fresh `pg_dump` and both `dump.rdb` files immediately before the patch. This repo pins PostgreSQL 15 because preflight requires ≥ 15.0.

## Channel

Channel `threescale-2.16` comes from `values-216-external.yaml`. The patch changes `extraValueFiles`. Do not edit the Subscription by hand. Argo overwrites that edit. The same file sets `externalComponents`, Redis auth, and `configMode: persist`.

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```

If the operator is at 0 replicas, scale the Deployment that exists in `3scale`. On 0.12 and 0.13 it is `threescale-operator-controller-manager-v2`.

Once `system-app-pre` succeeds, rollback is the fresh dump. There is no OLM downgrade.

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
