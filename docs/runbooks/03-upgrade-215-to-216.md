# Upgrade del operador 3scale 2.15 → 2.16

Requisito: system PostgreSQL ≥ 15.0 y Redis ≥ 7.2 **ya externalizados** (`externalComponents` en true). Si las versiones no cumplen, el operador 2.16 se instala pero **no** completa el upgrade de la instancia.

## Preflight

La versión del servidor, antes de cambiar el canal. `psql --version` es el cliente.

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'SELECT version();'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

Tomar un `pg_dump` y los dos `dump.rdb` frescos inmediatamente antes del parche. Este repo fija PostgreSQL 15 porque el preflight exige ≥ 15.0.

## Canal

El canal `threescale-2.16` sale de `values-216-external.yaml`. El parche cambia `extraValueFiles`. No editar la Subscription a mano. Argo pisa ese cambio. El mismo archivo pone `externalComponents`, auth de Redis y `configMode: persist`.

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```

Si el operador está en 0 réplicas, escalar el Deployment que exista en `3scale`. En 0.12 y 0.13 es `threescale-operator-controller-manager-v2`.

Desde que `system-app-pre` termina bien, el rollback es el dump fresco. No hay downgrade de OLM. El operador no sube `system-app` ni `system-sidekiq` desde 0; escalar esos dos desde `$HOME/3scale-replicas-before-cutover.json`.

Si `system-app-pre` falla con `ECONNREFUSED` a `backend-listener:3000`, escalar `backend-listener` a 1, esperar Ready, borrar el Job `system-app-pre` y anotar `apps.3scale.net/reconcile-now`. Los pods `system-searchd-manticore-reindex` en Error de antes de que `system-app` estuviera arriba se pueden borrar cuando un Job de reindex posterior queda Complete. El título **Access Restricted** del portal de desarrollador es el access code, no una ruta caída.

Esperar pods listos. Anotaciones esperadas en el APIManager:

```text
apps.3scale.net/apimanager-threescale-version: "2.16"
apps.3scale.net/threescale-operator-version: "0.13.x"
```

APIcast operator-based, si aplica, tiene su propio canal 2.16 (capítulo 2 de la guía de migración).

## Si `system-app-pre` falla con `permission denied for schema public`

PostgreSQL 15 revoca `CREATE` en `public` salvo al dueño del schema. Tras un restore hecho como `postgres`, el usuario `system` no puede migrar. Comando completo en [01-externalize-postgresql.md](01-externalize-postgresql.md) (sección GRANT). Borrar el Job `system-app-pre` y dejar que el operador lo recree.

## Si el preflight de versión falla

Subir PostgreSQL/Redis a las mínimas y dejar que el operador 2.16 reintente (cada ~10 minutos) o reescalar el controller del operador.
