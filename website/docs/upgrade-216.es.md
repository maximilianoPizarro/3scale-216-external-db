# Actualizar operador a 2.16

**Requisito:** PostgreSQL system ≥ 15.0 y Redis ≥ 7.2 ya externalizados (`externalComponents` marcado). Si las versiones no cumplen el preflight, el operador 2.16 se instala pero **no completa** el upgrade de la instancia.

## Preflight

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- psql --version
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

## Canal OLM

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

## Si `system-app-pre` falla: `permission denied for schema public`

PostgreSQL 15 revoca `CREATE` en `public` salvo al dueño del schema. Tras un restore hecho como `postgres`, el usuario `system` no puede migrar:

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

Borrar el Job `system-app-pre` y dejar que el operador lo recree. Este GRANT debería aplicarse ya en [Externalizar PostgreSQL](externalize-postgresql.es.md) — repetir si se omitió.

## Si el preflight de versión falla

Subir PostgreSQL/Redis a las mínimas y dejar que el operador 2.16 reintente (cada ~10 minutos) o reescalar el controller del operador.
