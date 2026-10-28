# Upgrade 3scale operator 2.15 → 2.16

Requirement: system PostgreSQL ≥ 15.0 and Redis ≥ 7.2 **already externalized** and verified on 2.15 (`/values-215-external.yaml`). If the versions do not meet the preflight, the 2.16 operator installs but **does not** complete the instance upgrade.

## Preflight

Server version, before switching the channel. `psql --version` is the client.

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'SELECT version();'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

Take a fresh `pg_dump` and both `dump.rdb` files immediately before the patch. This repo pins PostgreSQL 15 because the preflight requires ≥ 15.0.

OpenShift must be on the matrix for both 2.15 and 2.16 (today: 4.12, 4.14, 4.16–4.20; 4.13 and 4.15 are not listed). If the Subscription uses manual approval, approve each InstallPlan; the next one appears only after the previous one installed.

## Channel

Channel `threescale-2.16` comes from `values-216-external.yaml`. The patch changes `extraValueFiles`. Do not edit the Subscription by hand. Argo overwrites that change. That file only switches the channel: `externalComponents`, auth, and `persist` already come from `/values-215-external.yaml`.

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```

If the operator is at 0 replicas, scale the Deployment that exists in `3scale`. On 0.12 and 0.13 it is `threescale-operator-controller-manager-v2`.

Once `system-app-pre` succeeds, rollback is the fresh dump. There is no OLM downgrade. The operator does not raise `system-app` or `system-sidekiq` from 0; scale those two from `$HOME/3scale-replicas-before-cutover.json`. Have `backend-listener` Ready before the Job runs.

If `system-app-pre` fails with `ECONNREFUSED` to `backend-listener:3000`, scale `backend-listener` to 1, wait until Ready, delete Job `system-app-pre`, and annotate `apps.3scale.net/reconcile-now`. Pods `system-searchd-manticore-reindex` in Error from before `system-app` was up can be deleted once a later reindex Job is Complete. The developer portal title **Access Restricted** is the access code, not a down route.

Wait for pods Ready. Expected APIManager annotations:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

If a separate APIcast operator exists, its channel also moves to `threescale-2.16` in a different window (chapter 2 of the guide). The Pattern only moves the 3scale Subscription. The expected annotation is `apicast.apps.3scale.net/operator-version: "0.13.x"`.

`insecure_skip_verify: "true"` only if capability CRs already exist (Product, Backend, OpenAPI, Tenant, and similar) and the operator fails verifying the certificate. It does not apply to the APIManager.

## If `system-app-pre` fails with `permission denied for schema public`

PostgreSQL 15 revokes `CREATE` on `public` except for the schema owner. After a restore done as `postgres`, user `system` cannot migrate. Full command in [01-externalize-postgresql.md](01-externalize-postgresql.md) (GRANT section). Delete Job `system-app-pre` and let the operator recreate it.

## If version preflight fails

Raise PostgreSQL/Redis to the minimums and let the 2.16 operator retry (about every 10 minutes) or reschedule the operator controller.
