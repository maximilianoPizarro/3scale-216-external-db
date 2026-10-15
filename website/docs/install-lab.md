# Install 3scale 2.15 (lab)

Install the **2.15 3scale operator** and an APIManager with **embedded** PostgreSQL and Redis before you externalize. The install path is the [Pattern CR](pattern-cr.md). `values-215.yaml` keeps `threescale.externalDb.enabled` false.

Complete [Prerequisites](prerequisites.md) first. Stop if OperatorHub has no channel `threescale-2.15` or the cluster has no ReadWriteMany StorageClass. Do not substitute the single-node 2.16 Pattern for this page.

## 1. Install with the Pattern CR

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
oc get applications -n vp-gitops
oc -n 3scale get csv,subscription,pods
```

Wait for CSV `Succeeded` and pod `threescale-operator-controller-manager-v2`. The Subscription comes from `clusterGroup.subscriptions` in `values-hub.yaml`, overridden to channel `threescale-2.15` by `values-215.yaml`.

## 2. Provide RWX volume for `system-storage`

3scale requires **ReadWriteMany** for PVC `system-storage`. On AWS, `gp3-csi` is RWO. The PVC stays Pending (`Volume capabilities not supported`).

On AWS lab clusters: create an EFS filesystem in the cluster VPC (mount targets + TCP 2049 from node security groups) and a StorageClass named `efs-sc`. `values-215.yaml` sets `threescale.storage.systemStorageClass` to that name. The APIManager chart reads it. The apps domain comes from `global.localClusterDomain`, which the operator injects. Do not put the sandbox hostname in git.

```bash
oc get sc efs-sc
oc -n 3scale get apimanager,pods,pvc
```

If `system-storage` was created Pending against `gp3-csi` (APIManager applied before the RWX StorageClass):

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
```

When the APIManager is healthy, continue with [Externalize PostgreSQL](externalize-postgresql.md) and [Externalize Redis](externalize-redis.md).

## 4. Switch the operator channel to 2.16 (only after externalization)

Change `spec.extraValueFiles` on the Pattern from `/values-cutover.yaml` to `/values-216-external.yaml`. That file sets channel `threescale-2.16`, `externalComponents`, Redis auth, and `threescale.redis.configMode: persist`. Leave `systemStorageClass` on the ReadWriteMany class.
