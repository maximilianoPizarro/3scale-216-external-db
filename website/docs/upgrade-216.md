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

`system-app-pre` runs the 2.16 migrations against the external database. From the moment that job succeeds, rollback is a restore of the fresh dump. There is no OLM downgrade.

If `system-app-pre` fails with `ECONNREFUSED` to `backend-listener:3000`, the job started while `backend-listener` was still at 0 replicas. Scale the listener to 1 and wait until it is Ready. Then delete the Job and annotate the APIManager:

```bash
oc scale deployment/backend-listener -n 3scale --replicas=1
oc rollout status deployment/backend-listener -n 3scale
oc delete job system-app-pre -n 3scale
oc annotate apimanager apimanager -n 3scale apps.3scale.net/reconcile-now="$(date +%s)" --overwrite
```

The operator does not raise `system-app` or `system-sidekiq` from 0 after the maintenance scale-down. Scale both yourself. The product stays down while those two are at 0, even when the CSV is Succeeded.

Pods `system-searchd-manticore-reindex` in Error from before `system-app` was up can be deleted once a later reindex Job is Complete. The developer portal page titled **Access Restricted**, with a form posting to `/access_code`, is the portal access code. The route is up.

## If `system-app-pre` fails: `permission denied for schema public`

PostgreSQL 15 revokes `CREATE` on schema `public` except for the schema owner. After a restore done as `postgres`, user `system` cannot run migrations.

!!! warning "PostgreSQL 15 grant required"
    Run the full `GRANT USAGE, CREATE ON SCHEMA public` command during externalization — [Grant CREATE on schema `public`](externalize-postgresql.md#grant-create-on-schema-public). Delete the `system-app-pre` Job and let the 3scale operator recreate it.

## If version preflight fails

Upgrade PostgreSQL and Redis to the minimum versions. Let the 3scale operator 2.16 retry (approximately every 10 minutes) or rescale the operator controller.
