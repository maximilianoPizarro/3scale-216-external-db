# Instalar el operador 3scale en un cluster de prueba

La instalación es el Pattern CR `examples/pattern-cr/hub-215.yaml`. Hace falta el canal `threescale-2.15`. Sin ese canal, parar. No sustituir este runbook por `hub-216-singlenode.yaml`.

EFS es el camino ReadWriteMany: StorageClass `efs-sc`. Sin EFS, la alternativa de laboratorio es Local Storage Operator (`redhat-operators`, canal `stable`, `OwnNamespace`, namespace `openshift-local-storage`) y `examples/local-storage/localvolume.yaml`. Reemplazar `NODE_NAME` y la ruta del disco. Esa clase también se llama `efs-sc`. No instalar EFS y el LocalVolume a la vez.

El operador crea `system-storage` como ReadWriteMany. El PV local y `gp3-csi` son ReadWriteOnce. Recrear el PVC como ReadWriteOnce con el mismo `ownerReference`. En 4.21 de un nodo, el mismo recreado usa `gp3-csi` y 100Mi.

## 1. Pattern

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
oc get applications -n vp-gitops
oc -n 3scale get csv,subscription,pods
```

Esperar CSV `Succeeded` y el pod `threescale-operator-controller-manager-v2`.

## 2. Volumen RWX para `system-storage`

3scale pide **ReadWriteMany** para el PVC `system-storage`. En AWS, `gp3-csi` es RWO y el PVC queda Pending.

Crear un filesystem EFS en la VPC del cluster (mount targets + TCP 2049 desde el SG de los nodos), instalar `aws-efs-csi-driver-operator` y una StorageClass `efs-sc`. `values-215.yaml` ya apunta `threescale.storage.systemStorageClass` a ese nombre. El dominio de apps lo inyecta el operador. No guardarlo en git.

```bash
oc get sc efs-sc
oc -n 3scale get apimanager,pods,pvc
```

Si `system-storage` nació Pending contra `gp3-csi`:

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
```

Cuando el APIManager esté healthy, seguir [01-externalize-postgresql.md](01-externalize-postgresql.md) y [02-externalize-redis.md](02-externalize-redis.md).

## 3. Values después de externalizar

Tras cargar Redis y `BGREWRITEAOF`, pasar a `/values-215-external.yaml` (2.15 sobre las bases externas). Tras la verificación de 2.15 y el dump fresco, pasar a `/values-216-external.yaml` (solo el canal):

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-215-external.yaml"]}}'
# after 2.15 verification and fresh dump:
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```
