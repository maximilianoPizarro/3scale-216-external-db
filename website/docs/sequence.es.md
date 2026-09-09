# Secuencia de migración

Pasos para Linux/bash. Alineado con `docs/runbooks/00-secuencia-y-matriz.md` del repositorio.

## Orden de operaciones

1. **Instalar 3scale 2.15** en un cluster de prueba — operador + APIManager con bases embebidas ([Instalar 3scale 2.15 (lab)](install-lab.es.md)).
2. **Confirmar la matriz**: versión de OpenShift soportada por 2.15 **y** 2.16; último CSV en el canal `threescale-2.15`.
3. **Instantánea / backup** de PVC y secrets (`system-database`, `system-redis`, `backend-redis`).
4. **Ventana de mantenimiento**: escalar a 0 el operador 3scale y los componentes **excepto** la base que se está volcando.
5. **Externalizar PostgreSQL** 10 → 15 in-cluster ([Externalizar PostgreSQL](externalize-postgresql.es.md)).
6. **Externalizar Redis** 6 → 7 in-cluster ([Externalizar Redis](externalize-redis.es.md)).
7. Marcar `spec.externalComponents` en el APIManager (en los runbooks de PostgreSQL y Redis).
8. **Restaurar réplicas**, validar Admin Portal, Developer Portal y APIcast.
9. **Actualizar el operador** al canal `threescale-2.16` ([Actualizar operador a 2.16](upgrade-216.es.md)).
10. **Actualizar OpenShift** después, si aplica, según [Supported Configurations](https://access.redhat.com/articles/2798521).

!!! warning "No combinar upgrades"
    No ejecutar el upgrade de 3scale y el de OpenShift en la misma ventana de mantenimiento.

## Overlays de laboratorio vs producción

| Overlay | StorageClass | Uso |
|---------|--------------|-----|
| `lab` / `lab-persist` | `gp3-csi` (ejemplo) | Clusters de prueba |
| `prod` / `prod-persist` | Por defecto del cluster | Entornos tipo producción |

El procedimiento 3scale es el mismo; solo cambian los valores por defecto de almacenamiento.

## Opciones de despliegue

=== "GitOps (recomendado)"

    ```bash
    # Fase 1: operador 2.15 + APIManager
    oc apply -k gitops/
    oc apply -k gitops/rhacm/              # managed cluster vía hub ACM

    # Fase 2: BDD externas (crear antes el secret system-database en 3scale-db)
    oc apply -k gitops/external-db
    oc apply -k gitops/rhacm/external-db
    ```

=== "Kustomize (sin Argo CD)"

    ```bash
    oc apply -k kustomize/overlays/lab-operator
    oc apply -k kustomize/overlays/lab-efs
    oc apply -k kustomize/overlays/lab-apimanager
    # tras dump/restore:
    oc apply -k kustomize/overlays/lab
    ```

Ver [GitOps y RHACM](gitops.es.md) para el orden por waves y Placement de RHACM.
