# Motivación de este repositorio

A partir de **3scale 2.16**, el operador **deja de reconciliar** estas bases embebidas:

| Componente | Qué cambia en 2.16 |
|------------|-------------------|
| **PostgreSQL** (base system) | Ya no la gestiona el operador |
| **Redis** (system y backend) | Ya no las gestiona el operador |
| **Zync database** | Puede seguir interna (gestionada por el operador) |

Hay que **externalizar** esas bases **antes** de actualizar el operador a 2.16. Si las versiones no cumplen el preflight de 2.16 (PostgreSQL ≥ 15.0, Redis ≥ 7.2), el operador se instala pero **no completa** el upgrade de la instancia.

## External ≠ fuera del cluster

En la documentación de Red Hat, *external* significa que la base queda **fuera del ciclo de vida de la instalación 3scale** — el operador no la crea, parchea ni reconcilia. La base **puede seguir en el mismo cluster OpenShift**, por ejemplo en un namespace dedicado como `3scale-db`.

Este repositorio **no** es una guía de migración a RDS u off-cluster. Ofrece:

- **Runbooks** de dump/restore (PostgreSQL 10 → 15, Redis 6 → 7)
- Manifiestos **Kustomize** para imágenes RHSCL self-managed in-cluster
- Patrones **GitOps** (OpenShift GitOps / Argo CD y RHACM)

## Qué no cubre este repo

- Bases gestionadas en nube (RDS, Azure Database, etc.)
- Redis Cluster (no soportado por Red Hat para 3scale)
- Procedimientos específicos de Windows en este sitio — usar los runbooks `01-bis` y `02-bis` del repositorio, enlazados desde el [README](https://github.com/maximilianoPizarro/3scale-migration-216#windows--git-bash)

## Siguientes pasos

- [Documentación oficial de Red Hat](official-docs.es.md)
- [Versiones probadas](tested-versions.es.md)
- [Secuencia de migración](sequence.es.md)
