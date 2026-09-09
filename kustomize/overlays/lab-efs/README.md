# RWX en laboratorio AWS (EFS CSI)

`gp3-csi` es RWO. El PVC `system-storage` de 3scale exige **ReadWriteMany**. En AWS el camino soportado es EFS + AWS EFS CSI Driver Operator.

## 1. Filesystem EFS

En la misma VPC y región del cluster:

1. Crear un filesystem EFS (cifrado, bursting).
2. Security group que permita TCP **2049** desde el SG de los nodos (`*-node`).
3. Mount target en cada subnet privada de compute.

Anotar el `FileSystemId` (`fs-…`) en `kustomization.yaml` (patch `fileSystemId`).

## 2. Operador CSI y StorageClass

```bash
oc apply -k kustomize/overlays/lab-efs
oc -n openshift-cluster-csi-drivers get csv,pods | grep efs
oc get clustercsidriver efs.csi.aws.com
oc get sc efs-sc
```

CSV `Succeeded` y DaemonSet `aws-efs-csi-driver-node` listo en todos los nodos **antes** del APIManager.

## 3. APIManager

El overlay `lab-apimanager` apunta `spec.system.fileStorage.persistentVolumeClaim.storageClassName` a `efs-sc`. Aplicarlo **después** de que exista esa StorageClass.
