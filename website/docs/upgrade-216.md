# Upgrade operator to 2.16

The channel `threescale-2.16` comes from `values-216-external.yaml`. The command below changes Pattern `extraValueFiles`. It does not edit the Subscription by hand. Argo renders the Subscription from that file and overwrites a manual channel patch.

Run this page only after both cutover cycles, the 2.15 smoke test, and a **fresh** `pg_dump` plus both `dump.rdb` files. See [Migration sequence](sequence.md).

## Preflight, before the channel switch

Check the **server** version. `psql --version` prints the client and is not the preflight.

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'SELECT version();'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

PostgreSQL must be ≥ 15.0. Redis must be ≥ 7.2. This repository pins PostgreSQL 15 because the operator preflight rejects anything older.

## Switch the channel

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```

That file also sets `externalComponents`, Redis auth, and `configMode: persist`. ExternalSecret rewrites the connection Secrets. Do not patch those Secrets or the APIManager yourself.

If the operator Deployment is at 0 replicas, scale the Deployment that exists in namespace `3scale` back to 1. On CSV 0.12 and 0.13 the name is `threescale-operator-controller-manager-v2`. The name can change:

```bash
oc get deploy -n 3scale -o name
oc scale deployment threescale-operator-controller-manager-v2 -n 3scale --replicas=1
```

Wait until CSV `3scale-operator.v0.13.x` is `Succeeded`. Expected APIManager annotations:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

`system-app-pre` runs 2.16 migrations against the external database. From the moment that job succeeds, writes live on the external database. Scaling the embedded databases back up loses those writes. Rollback is a restore of the fresh dump. There is no OLM downgrade.

If `system-app-pre` fails with `ECONNREFUSED` to `backend-listener:3000`, the job started while `backend-listener` was still at 0 replicas. Scale the listener to 1 and wait until it is Ready. Then delete the Job and annotate the APIManager so the operator recreates it:

```bash
oc scale deployment/backend-listener -n 3scale --replicas=1
oc rollout status deployment/backend-listener -n 3scale
oc delete job system-app-pre -n 3scale
oc annotate apimanager apimanager -n 3scale apps.3scale.net/reconcile-now="$(date +%s)" --overwrite
```

The operator does not raise `system-app` or `system-sidekiq` from 0 after the maintenance scale-down. Scale both from `$HOME/3scale-replicas-before-cutover.json`. The product stays down while those two are at 0, even when CSV `3scale-operator.v0.13.x` is Succeeded and preflights pass.

Pods `system-searchd-manticore-reindex` in Error from before `system-app` was up can be deleted once a later reindex Job is Complete. The developer portal page titled **Access Restricted**, with a form posting to `/access_code`, is the portal access code. The route is up.

## If `system-app-pre` fails: `permission denied for schema public`

PostgreSQL 15 revokes `CREATE` on schema `public` except for the owner. `ALTER SCHEMA public OWNER TO system` is the step that lets migrations run. `GRANT CREATE` alone is the smaller privilege and is not a substitute. See [Externalize PostgreSQL](externalize-postgresql.md).

## If version preflight fails

Fix PostgreSQL or Redis before retrying. The 2.16 operator checks about every 10 minutes. Do not patch `OperatorCondition` by hand.
