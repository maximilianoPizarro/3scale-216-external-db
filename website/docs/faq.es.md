# FAQ de operación

Preguntas habituales al pasar de 3scale 2.15 (BDD embebidas) a 2.16, con PostgreSQL y Redis **in-cluster** pero **fuera del ciclo de vida del operador 3scale**.

## ¿“External” implica sacar las BDD del cluster?

No. *External* significa que las bases quedan **fuera del ciclo de vida del operador 3scale** — pueden seguir in-cluster (por ejemplo namespace `3scale-db`). Explicación completa, tabla de reconciliación y límites del repo: [Motivación](why.es.md).

## ¿Quién opera logs y persistencia en disco?

Tras `externalComponents`, operás PostgreSQL y ambos Redis en `3scale-db` (pods, PVC, imágenes, backups, logs). El operador 3scale sigue gestionando `system-app`, APIcast y Zync. Matriz de ownership y checklist de día 2: [Operación día 2](day-2.es.md). Motivación: [Motivación](why.es.md).

## ¿Qué versiones de imagen hay que fijar?

!!! warning "Requisito de preflight"
    PostgreSQL ≥ 15.0 (system) y Redis ≥ 7.2 (system + backend). El operador 3scale 2.16 lo comprueba cada ~10 minutos.

Imágenes usadas en la guía oficial y este repo:

- `registry.redhat.io/rhel9/postgresql-15`
- `registry.redhat.io/rhel9/redis-7`

Anclar **digest SHA-256** del catálogo de Red Hat. No anclar el tag flotante.

## Redis restore vs persistencia

Correr Redis en modo restore (`save ""`, `appendonly no`) solo durante el cutover para cargar `dump.rdb`. Después pasar a persistencia (`lab-persist` o `redis-config-persist`). Sin ese paso, un restart pierde datos.

Checklist de día 2 (backups, digest, path de GitOps): [Operación día 2](day-2.es.md).

## ¿Se puede probar en OpenShift 4.19 si producción está en un minor menor?

Sí. Usar 4.19 para validar 2.16 con BDD self-managed. En el cluster a migrar, confirmar que el OCP actual entra en la matriz de **2.15 y 2.16**. Secuencia: último micro de 2.15 → externalizar PostgreSQL y Redis **en 2.15** → operador 3scale 2.16 → upgrade de OpenShift después.

## ¿Dónde está el procedimiento completo?

Runbooks detallados en el repositorio:

1. `docs/runbooks/00-secuencia-y-matriz.md`
2. `docs/runbooks/01-externalize-postgresql.md`
3. `docs/runbooks/02-externalize-redis.md`
4. `docs/runbooks/03-upgrade-215-to-216.md`
5. `docs/runbooks/04-ops-logs-persistencia-imagenes.md`
6. `docs/runbooks/06-day-2.md`

En Windows (Git Bash), usar `docs/runbooks/01-bis-externalize-postgresql-windows.md` y `docs/runbooks/02-bis-externalize-redis-windows.md`. Referencia: `docs/faq-externalizacion.md`.
