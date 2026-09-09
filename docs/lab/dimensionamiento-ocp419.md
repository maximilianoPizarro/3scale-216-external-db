# Laboratorio OpenShift 4.19

Perfil de referencia para probar 3scale 2.15 → 2.16 con PostgreSQL y Redis in-cluster. El procedimiento no depende de AWS; los instance types son un ejemplo de cloud.

## Perfil de referencia (AWS)

| Parámetro | Valor |
|-----------|--------|
| OpenShift | 4.19 |
| Control plane | 3 × m6a.4xlarge (16 vCPU, 64 GiB) |
| Compute | 3 × m6a.4xlarge |
| UI de workshop | desactivada |

3scale y las BDD extra corren en **compute**, no en el control plane. Tres workers de este tamaño cubren 2.15 embebido **más** PostgreSQL 15 y dos Redis 7 durante la ventana (PVC y CPU a la vez).

m6a.2xlarge en compute es el piso. m8a.4xlarge no añade capacidad frente a m6a.4xlarge.

En clusters no AWS: equivalente ~16 vCPU / 64 GiB por worker × 3.

## Almacenamiento

Hace falta cuota de volúmenes RWO para los PVC embebidos de 2.15 **y** para:

- `postgresql-data-external`
- `backend-redis-storage-external`
- `system-redis-storage-external`

En el overlay `lab` la StorageClass de ejemplo es `gp3-csi`.

`system-storage` (APIManager) necesita **RWX**. En AWS de laboratorio: EFS + overlay `kustomize/overlays/lab-efs` (`efs-sc`). `gp3-csi` no sirve para ese PVC.

## Software en el cluster

- Pull secret a `registry.redhat.io`
- OperatorHub: 3scale 2.15 (instalación inicial) y canal 2.16 para el salto
- OpenShift GitOps opcional: fase 1 `oc apply -k gitops/`; BDD `oc apply -k gitops/external-db`
