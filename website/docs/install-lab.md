# Install 3scale 2.15 (lab)

Install the **2.15 3scale operator** and an APIManager with **embedded** PostgreSQL and Redis before you externalize. The install path is the [Pattern CR](pattern-cr.md). `values-215.yaml` keeps `threescale.externalDb.enabled` false.

Complete [Prerequisites](prerequisites.md) first. Stop if OperatorHub has no channel `threescale-2.15`. Do not substitute the single-node 2.16 Pattern for this page.

## 1. Install with the Pattern CR

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
oc get applications -n vp-gitops
oc -n 3scale get csv,subscription,pods
```

Wait for CSV `Succeeded` and the operator pod. On CSV 0.12 the Deployment is `threescale-operator-controller-manager-v2`. The Subscription comes from `clusterGroup.subscriptions` in `values-hub.yaml`, overridden to channel `threescale-2.15` by `values-215.yaml`.

## 2. ReadWriteMany for `system-storage`

The 3scale operator creates PVC `system-storage` as **ReadWriteMany**. The chart only sets `storageClassName`. Access modes are immutable.

`values-215.yaml`, `values-cutover.yaml`, and `values-216-external.yaml` set `threescale.storage.systemStorageClass` to `efs-sc`. On AWS, create an EFS filesystem in the cluster VPC (mount targets and TCP 2049 from the node security groups) and a StorageClass named `efs-sc`. The apps domain comes from `global.localClusterDomain`. Do not put the sandbox hostname or the filesystem id in git.

```bash
oc get sc efs-sc
oc -n 3scale get apimanager,pods,pvc
```

### Lab fallback: Local Storage Operator

When the cluster has no EFS, install Local Storage Operator (`redhat-operators`, channel `stable`, install mode `OwnNamespace`, namespace `openshift-local-storage`) and apply `examples/local-storage/localvolume.yaml`. Replace `NODE_NAME` and the device path. The example creates a StorageClass also named `efs-sc`, so the value files stay unchanged.

Do not install EFS CSI and this LocalVolume with the same class name at the same time.

The local PV is `ReadWriteOnce` and pins pods to that node. It is not a multi-node solution. The operator still requests `ReadWriteMany`, so the PVC stays Pending. Recreate it as `ReadWriteOnce` with the same labels and `ownerReference` as the object the operator created. Multiple pods on that one node can mount the RWO volume.

On the single-node 4.21 scenario the same recreate applies to `gp3-csi`: delete the Pending RWX PVC and create it again as `ReadWriteOnce`, size `100Mi`, class `gp3-csi`, with the APIManager `ownerReference`.

## 3. Switch the value file only after externalization

Change `spec.extraValueFiles` from `/values-cutover.yaml` to `/values-216-external.yaml` after the fresh dump and the 2.15 smoke test. That file sets channel `threescale-2.16`. Leave `systemStorageClass` on `efs-sc` for the migration scenario.
