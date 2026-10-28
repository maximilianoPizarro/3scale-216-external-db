# FAQ de operación

Preguntas habituales al pasar de 3scale 2.15 (BDD embebidas) a 2.16, con PostgreSQL y Redis **in-cluster** pero **fuera del ciclo de vida del operador 3scale**.

## ¿“External” implica sacar las BDD del cluster?

No. *External* significa que las bases quedan **fuera del ciclo de vida del operador 3scale** — pueden seguir in-cluster (por ejemplo namespace `3scale-db`). Explicación completa, tabla de reconciliación y límites del repo: [Motivación](why.es.md).

## ¿Quién opera logs y persistencia en disco?

Tras `externalComponents`, quien opera el namespace es dueño de PostgreSQL y de ambos Redis en `3scale-db` (pods, PVC, imágenes, backups, logs). El operador 3scale sigue gestionando `system-app`, APIcast y Zync. Matriz de ownership y checklist de día 2: [Operación día 2](day-2.es.md). Motivación: [Motivación](why.es.md).

## ¿Qué versiones de imagen hay que fijar?

!!! warning "Requisito de preflight"
    PostgreSQL ≥ 15.0 (system) y Redis ≥ 7.2 (system + backend). El operador 3scale 2.16 lo comprueba cada ~10 minutos.

Imágenes usadas en la guía oficial y este repo:

- `registry.redhat.io/rhel9/postgresql-15`
- `registry.redhat.io/rhel9/redis-7`

Anclar **digest SHA-256** del catálogo de Red Hat. No anclar el tag flotante.

## Redis restore vs persistencia

Correr Redis en modo restore (`save ""`, `appendonly no`) solo durante el cutover, y solo porque `values-cutover.yaml` pone `allowRestore: true`. Antes de devolver tráfico, pasar a `/values-215-external.yaml` (`configMode: persist`). El canal 2.16 es `/values-216-external.yaml`. Sin el paso a persist, un restart pierde datos.

Checklist de día 2 (backups, digest, path de GitOps): [Operación día 2](day-2.es.md).

## El producto se ve caído después del scale-down

El operador no sube `system-app` ni `system-sidekiq` desde 0. Escalar los dos desde `$HOME/3scale-replicas-before-cutover.json`. Un CSV Succeeded y preflights en True no arrancan esos pods. Si `system-app-pre` falla con `ECONNREFUSED` a `backend-listener:3000`, escalar antes `backend-listener` a 1. Comandos: [Actualizar operador a 2.16](upgrade-216.es.md).

## El portal de desarrollador dice Access Restricted

Esa página, con un formulario que postea a `/access_code`, es el access code del portal. La ruta está sirviendo.

## Los pods de reindex de búsqueda están en Error

Los pods `system-searchd-manticore-reindex` que fallaron antes de que `system-app` estuviera arriba se pueden borrar cuando un Job de reindex posterior queda Complete.

## ¿Se puede probar en OpenShift 4.19 si producción está en un minor menor?

Sí. Usar 4.19 para validar 2.16 con BDD self-managed. En el cluster a migrar, confirmar que el OCP actual entra en la matriz de **2.15 y 2.16** (hoy: 4.12, 4.14, 4.16–4.20; 4.13 y 4.15 no están). Si la Subscription está en aprobación manual, aprobar cada InstallPlan. Secuencia: último micro de 2.15 → externalizar PostgreSQL y Redis **en 2.15** → verificar 2.15 sobre el restore → operador 3scale 2.16 → upgrade de OpenShift después. Un operador de APIcast aparte es otra ventana.

## ¿Dónde está el procedimiento completo?

El sitio cubre el procedimiento en inglés/español. Runbooks para clonar el repo:

**Inglés:** `docs/runbooks/en/` (`00`–`07`, incluye variantes Windows `01-bis` / `02-bis`).

**Español:** `docs/runbooks/` (mismos números).

En Windows (Git Bash), usar `docs/runbooks/01-bis-externalize-postgresql-windows.md` y `docs/runbooks/02-bis-externalize-redis-windows.md` (o las copias en `en/`). Referencia: `docs/faq-externalizacion.md`. Si el cutover falla: [Rollback](rollback.es.md).
