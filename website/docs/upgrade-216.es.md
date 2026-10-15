# Actualizar operador a 2.16

!!! warning "Requisito de preflight"
    Externalizar primero PostgreSQL system ≥ 15.0 y Redis ≥ 7.2 (`externalComponents` marcado).
    Si las versiones no cumplen, el operador 3scale 2.16 se instala pero el upgrade de la instancia no completa.

## Ejecutar comprobaciones de preflight

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- psql --version
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

## Cambiar el canal OLM

Cambiar la Subscription del operador 3scale al canal `threescale-2.16`. Aprobar InstallPlans si el approval es manual.

```bash
oc apply -k kustomize/overlays/operator-216
```

Esperar pods listos. Anotaciones esperadas en el APIManager:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

APIcast operator-based, si aplica, tiene su propio canal 2.16 (capítulo 2 de la guía de migración).

`system-app-pre` corre las migraciones de 2.16 contra la base externa. Desde que ese Job termina bien, el rollback es un restore del dump fresco. No hay downgrade de OLM.

Si `system-app-pre` falla con `ECONNREFUSED` a `backend-listener:3000`, el Job arrancó con `backend-listener` todavía en 0 réplicas. Escalar el listener a 1 y esperar a que esté Ready. Después borrar el Job y anotar el APIManager:

```bash
oc scale deployment/backend-listener -n 3scale --replicas=1
oc rollout status deployment/backend-listener -n 3scale
oc delete job system-app-pre -n 3scale
oc annotate apimanager apimanager -n 3scale apps.3scale.net/reconcile-now="$(date +%s)" --overwrite
```

El operador no sube `system-app` ni `system-sidekiq` desde 0 después del scale-down de mantenimiento. Escalar los dos a mano. El producto sigue caído mientras esos dos estén en 0, aunque el CSV esté Succeeded.

Los pods `system-searchd-manticore-reindex` en Error de antes de que `system-app` estuviera arriba se pueden borrar cuando un Job de reindex posterior queda Complete. La página del portal de desarrollador titulada **Access Restricted**, con un formulario que postea a `/access_code`, es el access code del portal. La ruta está arriba.

## Si `system-app-pre` falla: `permission denied for schema public`

PostgreSQL 15 revoca `CREATE` en `public` salvo al dueño del schema. Tras un restore hecho como `postgres`, el usuario `system` no puede migrar.

!!! warning "GRANT de PostgreSQL 15 obligatorio"
    Ejecutar el comando completo `GRANT USAGE, CREATE ON SCHEMA public` durante la externalización — [GRANT CREATE en schema `public`](externalize-postgresql.es.md#grant-create-en-schema-public). Borrar el Job `system-app-pre` y dejar que el operador 3scale lo recree.

## Si el preflight de versión falla

Subir PostgreSQL y Redis a las mínimas. Dejar que el operador 3scale 2.16 reintente (cada ~10 minutos) o reescalar el controller del operador.
