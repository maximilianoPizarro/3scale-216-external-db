# Versiones probadas

Los valores siguientes reflejan una **migración de laboratorio** en AWS. Sustituir los placeholders de los overlays antes de aplicar manifiestos. Este repositorio no incluye hostnames de sandbox ni IDs de EFS.

Matriz de producto: [Supported Configurations](https://access.redhat.com/articles/2798521).

!!! note "Reconfirmar la matriz antes de producción"
    Red Hat actualiza [Supported Configurations](https://access.redhat.com/articles/2798521) con los micro releases de producto. Confirmar versiones de OpenShift, PostgreSQL y Redis para **2.15 y 2.16** en el cluster destino antes de agendar la ventana de mantenimiento. Los valores de laboratorio de abajo son una instantánea, no sustituyen el artículo vigente.

## Entorno

| Capa | Valor probado |
|------|---------------|
| **OpenShift** | 4.19 en **AWS** para la migración. 4.21 de un nodo para un 2.16 directo. |
| **3scale origen** | 2.15.5 — CSV `0.12.5`, canal `threescale-2.15` |
| **3scale destino** | 2.16.4 — CSV `0.13.4`, canal `threescale-2.16` |
| **PostgreSQL** | 15 — `registry.redhat.io/rhel9/postgresql-15` |
| **Redis** | 7 — `registry.redhat.io/rhel9/redis-7` (system + backend) |
| **Instalación** | Validated Pattern. Los digest están en `values-global.yaml`. Ver [Anclar digest de imágenes](image-digests.es.md). |

Una instalación de OpenShift 4.21 de un solo nodo con `values-216-singlenode.yaml` es un 2.16 directo. No es esta migración 2.15. Ese escenario usa `gp3-csi` para `system-storage` porque hay un solo nodo.

## Almacenamiento

| Uso | StorageClass | Modo de acceso |
|-----|--------------|----------------|
| PVCs de PostgreSQL / Redis externos | `gp3-csi` | ReadWriteOnce |
| `system-storage` (almacenamiento de archivos 3scale) | `efs-sc` (driver EFS CSI) | ReadWriteMany |

En laboratorios AWS el camino ReadWriteMany es **EFS CSI** y la clase `efs-sc`. Sin EFS, Local Storage Operator puede publicar una clase con el mismo nombre. El PV local es ReadWriteOnce, así que hay que recrear `system-storage` como ReadWriteOnce. Ver [Instalar 3scale 2.15 (lab)](install-lab.es.md). No correr EFS y ese LocalVolume al mismo tiempo.

Este repo fija PostgreSQL 15. El preflight del operador exige ≥ 15.0, así que PostgreSQL 14 queda fuera de este procedimiento aunque la matriz de producto lo liste.

## Matriz soportada (referencia)

Para 3scale 2.16, Red Hat documenta:

- OpenShift: 4.12, 4.14, 4.16, 4.17, 4.18, 4.19, 4.20 (4.13 y 4.15 no están)
- PostgreSQL: 14, 15 (preflight del system DB exige ≥ 15.0)
- Redis: 7.2 (dos instancias)

Probar en OpenShift 4.19 valida el camino a 2.16 aunque producción use un minor anterior soportado. Actualizar OpenShift **después** de la migración 3scale. No combinar esos upgrades en la misma ventana de mantenimiento. Si la Subscription está en aprobación manual, aprobar cada InstallPlan; el siguiente aparece cuando el anterior se instaló.
