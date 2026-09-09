# Motivación de este repositorio

A partir de **3scale 2.16**, el operador 3scale **deja de reconciliar** estas bases embebidas:

| Componente | Qué cambia en 2.16 |
|------------|-------------------|
| **PostgreSQL** (base system) | El operador 3scale ya no la gestiona |
| **Redis** (system y backend) | El operador 3scale ya no las gestiona |
| **Zync database** | Puede seguir interna (gestionada por el operador) |

Hay que **externalizar** esas bases **antes** de actualizar el operador 3scale a 2.16.

!!! warning "Requisito de preflight"
    PostgreSQL ≥ 15.0 y Redis ≥ 7.2 son obligatorios antes del upgrade.
    Si las versiones no cumplen, el operador 3scale se instala pero el upgrade de la instancia no completa.

## External ≠ fuera del cluster

En la documentación de Red Hat, *external* significa que la base queda **fuera del ciclo de vida de la instalación 3scale**. El operador 3scale ya no la crea, parchea ni reconcilia.

La base **puede seguir in-cluster**, por ejemplo en un namespace dedicado como `3scale-db`.

Este repositorio **no** es una guía de migración a RDS u off-cluster. Ofrece:

- **Runbooks** de dump/restore (PostgreSQL 10 → 15, Redis 6 → 7)
- Manifiestos **Kustomize** para imágenes RHSCL self-managed in-cluster
- Patrones **GitOps** (OpenShift GitOps / Argo CD y RHACM)

## Qué no cubre este repo

- Bases gestionadas en nube (RDS, Azure Database y similares)
- Redis Cluster (Red Hat no lo soporta para 3scale)
- Topología o red de bases off-cluster

## Siguientes pasos

- [Requisitos previos](prerequisites.es.md)
- [Documentación oficial de Red Hat](official-docs.es.md)
- [Versiones probadas](tested-versions.es.md)
- [Secuencia de migración](sequence.es.md)
- [Operación día 2](day-2.es.md)
