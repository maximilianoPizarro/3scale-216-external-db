# Actualizar operador a 2.16

El canal `threescale-2.16` sale de `values-216-external.yaml`. El comando de abajo cambia `extraValueFiles` del Pattern. No edita la Subscription a mano. Argo renderiza la Subscription desde ese archivo y pisa un parche manual del canal.

Correr esta página solo después de los dos ciclos, del smoke test en 2.15 y de un `pg_dump` **fresco** más los dos `dump.rdb`. Ver [Secuencia de migración](sequence.es.md).

## Preflight, antes del cambio de canal

Comprobar la versión del **servidor**. `psql --version` imprime el cliente y no es el preflight.

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'SELECT version();'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

PostgreSQL tiene que ser ≥ 15.0. Redis tiene que ser ≥ 7.2. Este repositorio fija PostgreSQL 15 porque el preflight del operador rechaza una versión anterior.

## Cambiar el canal

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```

Ese archivo también pone `externalComponents`, auth de Redis y `configMode: persist`. ExternalSecret reescribe los Secrets de conexión. No parchear esos Secrets ni el APIManager a mano.

Si el Deployment del operador está en 0 réplicas, escalar a 1 el Deployment que exista en el namespace `3scale`. En los CSV 0.12 y 0.13 el nombre es `threescale-operator-controller-manager-v2`. El nombre puede cambiar:

```bash
oc get deploy -n 3scale -o name
oc scale deployment threescale-operator-controller-manager-v2 -n 3scale --replicas=1
```

Esperar a que el CSV `3scale-operator.v0.13.x` esté `Succeeded`. Anotaciones esperadas en el APIManager:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

`system-app-pre` corre las migraciones de 2.16 contra la base externa. Desde que ese Job termina bien, las escrituras viven en la base externa. Volver a escalar las bases embebidas pierde esas escrituras. El rollback es un restore del dump fresco. No hay downgrade de OLM.

Si `system-app-pre` falla con `ECONNREFUSED` a `backend-listener:3000`, el Job arrancó antes de que el listener estuviera listo. Borrar el Job y anotar el APIManager para que el operador lo recree:

```bash
oc annotate apimanager apimanager -n 3scale apps.3scale.net/reconcile-now="$(date +%s)" --overwrite
```

## Si `system-app-pre` falla: `permission denied for schema public`

PostgreSQL 15 revoca `CREATE` en el schema `public` salvo al dueño. `ALTER SCHEMA public OWNER TO system` es el paso que deja correr las migraciones. `GRANT CREATE` solo es el privilegio menor y no lo reemplaza. Ver [Externalizar PostgreSQL](externalize-postgresql.es.md).

## Si el preflight de versión falla

Corregir PostgreSQL o Redis antes de reintentar. El operador 2.16 comprueba más o menos cada 10 minutos. No parchear `OperatorCondition` a mano.
