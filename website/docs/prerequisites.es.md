# Requisitos previos

Completar esta lista antes de ejecutar `oc apply` o un dump. Confirmar versiones en [Supported Configurations](https://access.redhat.com/articles/2798521) y en la [guía de migración a 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index).

## Para quién es esto

- Administradores de OpenShift
- SREs de plataforma que operan 3scale in-cluster
- `cluster-admin` (o equivalente) para instalar operadores, crear namespaces y parchear el APIManager

## Versiones de cluster y producto

- Versión de OpenShift soportada por 3scale **2.15 y 2.16**
- 3scale en el canal `threescale-2.15` (último CSV) **antes** de externalizar
- **No** actualizar OpenShift en la misma ventana que el upgrade de 3scale

Este laboratorio se probó en OpenShift 4.19. Ver [Versiones probadas](tested-versions.es.md).

## Acceso y herramientas

- `oc` autenticado contra el cluster destino
- Pull a `registry.redhat.io` para las imágenes RHSCL
- Bash en Linux para dump/restore (Git Bash en Windows: runbooks `01-bis` / `02-bis` en `docs/runbooks/`)

## Almacenamiento

- StorageClass **ReadWriteMany** para `system-storage` (EFS CSI / `efs-sc` en el lab AWS)
- StorageClass **ReadWriteOnce** para los PVC in-cluster de PostgreSQL y Redis (`gp3-csi` en el lab AWS)

## Backup antes de la ventana de mantenimiento

- Instantánea o backup de PVC (`postgresql-data`, almacenamiento Redis, `system-storage`)
- Exportar los secrets `system-database`, `system-redis` y `backend-redis`
- Planear una ventana de mantenimiento. Durante dump y restore se escala a 0 el operador 3scale y la mayoría de los componentes.

!!! warning "Requisito de preflight"
    Tras la externalización, PostgreSQL debe ser ≥ 15.0 y Redis ≥ 7.2. Si no, el operador 3scale 2.16 se instala pero el upgrade de la instancia no completa.

## Qué no se hace en este repo

- Sacar las bases del cluster (RDS, Azure Database y similares)
- Activar Redis Cluster
- Combinar el upgrade de 3scale y el de OpenShift en una sola ventana

## Siguientes pasos

- [Documentación oficial](official-docs.es.md)
- [Secuencia de migración](sequence.es.md)
- [Instalar 3scale 2.15 (lab)](install-lab.es.md)
