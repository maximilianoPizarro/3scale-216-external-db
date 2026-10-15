# Instalar 3scale 2.15 (lab)

Instalar el **operador 3scale 2.15** y un APIManager con PostgreSQL y Redis **embebidos** antes de externalizar. La instalación es el [Pattern CR](pattern-cr.es.md). `values-215.yaml` deja `threescale.externalDb.enabled` en false.

Completar primero [Requisitos previos](prerequisites.es.md). Parar si OperatorHub no tiene el canal `threescale-2.15` o el cluster no tiene una StorageClass ReadWriteMany. No sustituir esta página por el Pattern de 2.16 en un solo nodo.

## 1. Instalar con el Pattern CR

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
oc get applications -n vp-gitops
oc -n 3scale get csv,subscription,pods
```

Esperar CSV `Succeeded` y el pod `threescale-operator-controller-manager-v2`. La Subscription sale de `clusterGroup.subscriptions` en `values-hub.yaml`, con canal `threescale-2.15` por `values-215.yaml`.

## 2. Proveer volumen RWX para `system-storage`

3scale exige **ReadWriteMany** para el PVC `system-storage`. En AWS, `gp3-csi` es RWO. El PVC queda Pending (`Volume capabilities not supported`).

En laboratorio AWS: crear un filesystem EFS en la VPC del cluster (mount targets + TCP 2049 desde el SG de nodos) y una StorageClass llamada `efs-sc`. `values-215.yaml` pone `threescale.storage.systemStorageClass` en ese nombre. El chart del APIManager lo lee. El dominio de apps lo inyecta el operador en `global.localClusterDomain`. No guardar el hostname del sandbox en git.

```bash
oc get sc efs-sc
oc -n 3scale get apimanager,pods,pvc
```

Si `system-storage` nació Pending contra `gp3-csi` (APIManager aplicado antes de la SC RWX):

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
```

Cuando el APIManager esté healthy, seguir con [Externalizar PostgreSQL](externalize-postgresql.es.md) y [Externalizar Redis](externalize-redis.es.md).

## 4. Cambiar el canal del operador a 2.16 (solo después de externalizar)

Cambiar `spec.extraValueFiles` del Pattern de `/values-cutover.yaml` a `/values-216-external.yaml`. Ese archivo pone el canal `threescale-2.16`, `externalComponents`, auth de Redis y `threescale.redis.configMode: persist`. Dejar `systemStorageClass` en la clase ReadWriteMany.
