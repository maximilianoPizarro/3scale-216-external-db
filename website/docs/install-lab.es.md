# Instalar 3scale 2.15 (lab)

Instalar el **operador 3scale 2.15** y un APIManager con PostgreSQL y Redis **embebidos** antes de externalizar. La instalación es el [Pattern CR](pattern-cr.es.md). `values-215.yaml` deja `threescale.externalDb.enabled` en false.

Completar primero [Requisitos previos](prerequisites.es.md). Parar si OperatorHub no tiene el canal `threescale-2.15`. No sustituir esta página por el Pattern de 2.16 en un solo nodo.

## 1. Instalar con el Pattern CR

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
oc get applications -n vp-gitops
oc -n 3scale get csv,subscription,pods
```

Esperar CSV `Succeeded` y el pod del operador. En el CSV 0.12 el Deployment es `threescale-operator-controller-manager-v2`. La Subscription sale de `clusterGroup.subscriptions` en `values-hub.yaml`, con canal `threescale-2.15` por `values-215.yaml`.

## 2. ReadWriteMany para `system-storage`

El operador 3scale crea el PVC `system-storage` como **ReadWriteMany**. El chart solo fija `storageClassName`. El access mode es inmutable.

`values-215.yaml`, `values-cutover.yaml` y `values-216-external.yaml` ponen `threescale.storage.systemStorageClass` en `efs-sc`. En AWS, crear un filesystem EFS en la VPC del cluster (mount targets y TCP 2049 desde el security group de los nodos) y una StorageClass llamada `efs-sc`. El dominio de apps lo inyecta el operador en `global.localClusterDomain`. No guardar el hostname del sandbox ni el id del filesystem en git.

```bash
oc get sc efs-sc
oc -n 3scale get apimanager,pods,pvc
```

### Alternativa de laboratorio: Local Storage Operator

Cuando el cluster no tiene EFS, instalar Local Storage Operator (`redhat-operators`, canal `stable`, modo `OwnNamespace`, namespace `openshift-local-storage`) y aplicar `examples/local-storage/localvolume.yaml`. Reemplazar `NODE_NAME` y la ruta del disco. El ejemplo crea una StorageClass también llamada `efs-sc`, así los values no cambian.

No instalar el CSI de EFS y este LocalVolume con el mismo nombre de clase al mismo tiempo.

El PV local es `ReadWriteOnce` y fija los pods a ese nodo. No es una solución de varios nodos. El operador igual pide `ReadWriteMany`, así que el PVC queda Pending. Recrearlo como `ReadWriteOnce` con las mismas labels y el mismo `ownerReference` del objeto que creó el operador. Varios pods en ese único nodo pueden montar el volumen RWO.

En el escenario de un nodo en 4.21 el mismo recreado aplica a `gp3-csi`: borrar el PVC RWX Pending y crearlo de nuevo como `ReadWriteOnce`, tamaño `100Mi`, clase `gp3-csi`, con el `ownerReference` del APIManager.

## 3. Cambiar los archivos de values después de cada paso del corte

Cambiar `spec.extraValueFiles` de `/values-cutover.yaml` a `/values-215-external.yaml` después de cargar el RDB y `BGREWRITEAOF`, antes de devolver tráfico en 2.15. Tras el dump fresco y la verificación de 2.15, pasarlo a `/values-216-external.yaml`. Ese último archivo solo pone el canal `threescale-2.16`. Dejar `systemStorageClass` en `efs-sc` para el escenario de migración.
