# Install the 3scale operator on a test cluster

The install is Pattern CR `examples/pattern-cr/hub-215.yaml`. Channel `threescale-2.15` is required. Stop if that channel is missing. Do not substitute `hub-216-singlenode.yaml`.

EFS is the ReadWriteMany path: StorageClass `efs-sc`. Without EFS, the lab fallback is Local Storage Operator (`redhat-operators`, channel `stable`, `OwnNamespace`, namespace `openshift-local-storage`) and `examples/local-storage/localvolume.yaml`. Replace `NODE_NAME` and the device path. That class is also named `efs-sc`. Do not install EFS and the LocalVolume together.

The operator creates `system-storage` as ReadWriteMany. The local PV and `gp3-csi` are ReadWriteOnce. Recreate the PVC as ReadWriteOnce with the same `ownerReference`. On single-node 4.21, the same recreate uses `gp3-csi` and 100Mi.

## 1. Pattern

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
oc get applications -n vp-gitops
oc -n 3scale get csv,subscription,pods
```

Wait for CSV `Succeeded` and pod `threescale-operator-controller-manager-v2`.

## 2. RWX volume for `system-storage`

3scale requires **ReadWriteMany** for PVC `system-storage`. On AWS, `gp3-csi` is RWO and the PVC stays Pending.

Create an EFS filesystem in the cluster VPC (mount targets + TCP 2049 from the node security group), install `aws-efs-csi-driver-operator`, and a StorageClass `efs-sc`. `values-215.yaml` already sets `threescale.storage.systemStorageClass` to that name. The operator injects the apps domain. Do not store it in git.

```bash
oc get sc efs-sc
oc -n 3scale get apimanager,pods,pvc
```

If `system-storage` was Pending against `gp3-csi`:

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
```

When the APIManager is healthy, continue with [01-externalize-postgresql.md](01-externalize-postgresql.md) and [02-externalize-redis.md](02-externalize-redis.md).

## 3. Value files after externalization

After loading Redis and `BGREWRITEAOF`, switch to `/values-215-external.yaml` (2.15 on the external databases). After the 2.15 verification and the fresh dump, switch to `/values-216-external.yaml` (channel only):

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-215-external.yaml"]}}'
# after 2.15 verification and fresh dump:
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```
