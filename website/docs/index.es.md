# Migración 3scale 2.15 → 2.16

Esta página es la guía del **Validated Pattern**. La versión **1.0.0** del selector es la guía anterior: Kustomize y GitOps, sin Pattern CR.

Este repositorio está pensado para **administradores de OpenShift** y **SREs de plataforma** que operan 3scale in-cluster y deben pasar de 2.15 a 2.16. Procedimiento de producto y matriz soportada: [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index).

Sirve para **externalizar** PostgreSQL (system) y Redis (system y backend) **in-cluster** antes de actualizar el operador 3scale a **2.16**. Las bases siguen en OpenShift. El operador 3scale deja de gestionarlas al marcar `externalComponents`.

Un corte de laboratorio suele llevar **unas pocas horas** cuando el cluster y el almacenamiento RWX ya están listos. En producción el tiempo depende del tamaño de las bases y de la ventana de mantenimiento.

!!! note "Paquete validado en laboratorio"
    Las versiones y los valores por defecto de almacenamiento reflejan una **migración de lab** — ver [Versiones probadas](tested-versions.es.md). Reconfirmar [Supported Configurations](https://access.redhat.com/articles/2798521) y adaptar placeholders (`REPLACE_*`) y StorageClasses al cluster antes de aplicar manifiestos.

Este repositorio usa el Validated Patterns Operator. No es una declaración de soporte de Red Hat. El entorno probado es AWS: OpenShift 4.19 para la migración 2.15 a 2.16, y OpenShift 4.21 de un nodo para una instalación directa de 2.16.

## Qué es este laboratorio

Una réplica de PostgreSQL y de cada Redis. No hay alta disponibilidad. Un drain de nodo o un rollout de imagen es un corte. El RPO es el último dump. El RTO es el tiempo de restaurar ese dump. Un paso posterior puede pasar PostgreSQL a un operador con HA y Redis a un servicio gestionado. Este repositorio no implementa ese paso.

El dump de PostgreSQL del laboratorio fue de 719027 bytes. Ese tamaño no es una estimación de producción.

## Qué incluye

| Área | Ubicación en el repo |
|------|----------------------|
| Pattern CR y values de cada escenario | `examples/pattern-cr/`, `values-*.yaml` |
| Charts Helm (APIManager, bases, ExternalSecret) | `charts/all/` |
| Runbooks operativos (para clonar) | `docs/runbooks/` (ES), `docs/runbooks/en/` (EN) |

## Ruta rápida

1. [Motivación](why.es.md)
2. [Requisitos previos](prerequisites.es.md)
3. [Instalar con un Pattern CR](pattern-cr.es.md)
4. [Secuencia de migración](sequence.es.md)
5. [Rotación de credenciales](credential-rotation.es.md)
6. [Operación día 2](day-2.es.md) (después del cutover)

Los comandos de este sitio asumen **Linux (bash)**. Para **Git Bash en Windows**, usar `docs/runbooks/01-bis-externalize-postgresql-windows.md` y `docs/runbooks/02-bis-externalize-redis-windows.md` en el repositorio.
