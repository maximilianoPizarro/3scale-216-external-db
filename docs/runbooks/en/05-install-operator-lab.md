# Install the 3scale operator on a test cluster

The install is Pattern CR `examples/pattern-cr/hub-215.yaml`. Channel `threescale-2.15` and a ReadWriteMany StorageClass named `efs-sc` are required. Stop if either is missing. Do not substitute `hub-216-singlenode.yaml`.

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

## 3. Channel 2.16 (only after externalizing)

```bash
oc patch pattern 3scale-216-external-db -n openshift-operators --type merge \
  -p '{"spec":{"extraValueFiles":["/values-216-external.yaml"]}}'
```
