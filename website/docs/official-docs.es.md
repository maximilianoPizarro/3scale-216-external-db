# Documentación oficial

Guías de Red Hat para esta migración:

## Guías principales

| Tema | Enlace |
|------|--------|
| **Migración a 3scale 2.16** (visión general) | [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index) |
| **Externalización de bases** | [Externalizing databases](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/externalizing-databases) |
| **Upgrade del operador 2.15 → 2.16** | [Upgrade 2.15 to 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/upgrade-operator) |
| **Configuraciones soportadas** | [Supported Configurations](https://access.redhat.com/articles/2798521) |

## Cómo se relaciona este repo con la guía

| Capítulo oficial | Este repositorio |
|------------------|------------------|
| PostgreSQL 10 upgrade — on-cluster | [Externalizar PostgreSQL](externalize-postgresql.es.md) + `kustomize/bases/postgresql` |
| Redis 6 upgrade — on-cluster | [Externalizar Redis](externalize-redis.es.md) + `kustomize/bases/redis-*` |
| Upgrade del operador | [Actualizar operador a 2.16](upgrade-216.es.md) + `kustomize/overlays/operator-216` |
| Instalación de laboratorio antes de externalizar | [Instalar 3scale 2.15 (lab)](install-lab.es.md) |
| Día 2 (bases self-managed) | [Operación día 2](day-2.es.md) + `docs/runbooks/06-day-2.md` |

Los pasos operativos detallados (español, para quien clona el repo) siguen en `docs/runbooks/`.
