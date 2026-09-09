# Migración 3scale 2.15 → 2.16

Este repositorio está pensado para **administradores de OpenShift** y **SREs de plataforma** que operan 3scale in-cluster y deben pasar de 2.15 a 2.16. Procedimiento de producto y matriz soportada: [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index).

Sirve para **externalizar** PostgreSQL (system) y Redis (system y backend) **in-cluster** antes de actualizar el operador 3scale a **2.16**. Las bases siguen en OpenShift. El operador 3scale deja de gestionarlas al marcar `externalComponents`.

Un corte de laboratorio suele llevar **unas pocas horas** cuando el cluster y el almacenamiento RWX ya están listos. En producción el tiempo depende del tamaño de las bases y de la ventana de mantenimiento.

## Qué incluye

| Área | Ubicación en el repo |
|------|----------------------|
| Bases y overlays Kustomize | `kustomize/` |
| Runbooks operativos (español) | `docs/runbooks/` |
| OpenShift GitOps / Argo CD | `gitops/` |
| Patrones RHACM (hub) | `gitops/rhacm/` |

## Ruta rápida

1. [Motivación](why.es.md)
2. [Requisitos previos](prerequisites.es.md)
3. [Documentación oficial de Red Hat](official-docs.es.md)
4. [Secuencia de migración](sequence.es.md)
5. [Versiones probadas](tested-versions.es.md)
6. [Operación día 2](day-2.es.md) (después del cutover)

!!! tip "Windows / Git Bash"
    Los comandos de este sitio asumen **Linux (bash)**. En **Git Bash**, leer primero [Windows / Git Bash](windows.es.md) y usar las pestañas **Windows / Git Bash** en los runbooks de PostgreSQL y Redis.
