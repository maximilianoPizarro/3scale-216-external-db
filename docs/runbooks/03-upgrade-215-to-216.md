# Upgrade del operador 3scale 2.15 → 2.16

Requisito: system PostgreSQL ≥ 15.0 y Redis ≥ 7.2 **ya externalizados** (`externalComponents` en true). Si las versiones no cumplen, el operador 2.16 se instala pero **no** completa el upgrade de la instancia.

## Preflight

En los pods de BDD self-managed:

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- psql --version
oc exec -n 3scale-db deploy/backend-redis-external -- redis-server --version
oc exec -n 3scale-db deploy/system-redis-external -- redis-server --version
```

## Canal OLM

Cambiar la Subscription del operador 3scale al canal `threescale-2.16`. Aprobar InstallPlans si el approval es manual.

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
