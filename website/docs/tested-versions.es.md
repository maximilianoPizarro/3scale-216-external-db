# Versiones probadas

Los valores siguientes reflejan una **migración de laboratorio** en AWS. Sustituir los placeholders de los overlays antes de aplicar manifiestos. Este repositorio no incluye hostnames de sandbox ni IDs de EFS.

## Entorno

| Capa | Valor probado |
|------|---------------|
| **OpenShift** | 4.19 en **AWS, self-managed** (IPI; sin bases gestionadas por ROSA) |
| **3scale origen** | 2.15.5 — CSV `0.12.5`, canal `threescale-2.15` |
| **3scale destino** | 2.16.4 — CSV `0.13.4`, canal `threescale-2.16` |
| **PostgreSQL** | 15 — `registry.redhat.io/rhel9/postgresql-15` |
| **Redis** | 7 — `registry.redhat.io/rhel9/redis-7` (system + backend) |

## Almacenamiento

| Uso | StorageClass | Modo de acceso |
|-----|--------------|----------------|
| PVCs de PostgreSQL / Redis externos | `gp3-csi` | ReadWriteOnce |
| `system-storage` (almacenamiento de archivos 3scale) | `efs-sc` (driver EFS CSI) | ReadWriteMany |

En laboratorios AWS donde el almacenamiento por defecto es solo RWO, hace falta **EFS CSI** para el PVC `system-storage`. Ver [Instalar 3scale 2.15 (lab)](install-lab.es.md).

## Matriz soportada (referencia)

Confirmar siempre en [Supported Configurations](https://access.redhat.com/articles/2798521). Para 3scale 2.16:

- OpenShift: 4.14, 4.16–4.19 (4.20+ en micros posteriores de 2.16)
- PostgreSQL: 14, 15 (preflight del system DB exige ≥ 15.0)
- Redis: 7.2 (dos instancias)

Probar en OpenShift 4.19 valida el camino a 2.16 aunque producción use un minor anterior soportado. Actualizar OpenShift **después** de la migración 3scale, no en la misma ventana de mantenimiento.
