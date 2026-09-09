# Install the 3scale operator on a test cluster

The database overlay **does not** install the operator. In the lab you need 3scale **2.15** with embedded PostgreSQL; then externalize and move the channel to 2.16.

## 1. Operator (OLM)

```bash
oc apply -k kustomize/overlays/lab-operator
oc -n 3scale get csv,subscription,pods
```

Wait for CSV `Succeeded` and pod `threescale-operator-controller-manager-v2`.

Catalog: `redhat-operators` / `openshift-marketplace`. On disconnected, change Subscription `spec.source`.

## 2. RWX volume for `system-storage`

3scale requires **ReadWriteMany** for PVC `system-storage`. On AWS, `gp3-csi` is RWO and the PVC stays Pending (`Volume capabilities not supported`).

On AWS lab: EFS filesystem in the cluster VPC (mount targets + TCP 2049 from node SG) and the EFS CSI overlay:

```bash
# fileSystemId in kustomize/overlays/lab-efs/kustomization.yaml
oc apply -k kustomize/overlays/lab-efs
oc -n openshift-cluster-csi-drivers get csv,pods | grep efs
oc get sc efs-sc
```

Details: [kustomize/overlays/lab-efs/README.md](../../../kustomize/overlays/lab-efs/README.md). On another cloud, replace `efs-sc` with an equivalent RWX StorageClass.

## 3. APIManager 2.15 (embedded PostgreSQL)

In `kustomize/overlays/lab-apimanager/kustomization.yaml` set the apps domain (`REPLACE_WILDCARD_DOMAIN`, e.g. `apps.cluster.example.com`). The overlay already points `fileStorage` to `efs-sc`.

```bash
oc apply -k kustomize/overlays/lab-apimanager
oc -n 3scale get apimanager,pods,pvc
```

If `system-storage` was Pending against `gp3-csi` (APIManager applied before RWX SC):

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
# If the operator does not recreate the PVC in ~1 min, create it manually with the same name,
# accessModes: [ReadWriteMany] and storageClassName: efs-sc
```

When the APIManager is healthy, continue with [01-externalize-postgresql.md](01-externalize-postgresql.md) (Windows/Git Bash: [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md)) and [02-externalize-redis.md](02-externalize-redis.md) (Windows/Git Bash: [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md)).

## 4. Channel 2.16 (only after externalizing)

```bash
oc apply -k kustomize/overlays/operator-216
```

GitOps phase 1 (operator + APIManager, not databases):

```bash
oc apply -k gitops/
# ACM hub:
oc apply -k gitops/rhacm/
```

Set `REPLACE_REPO_URL` in ApplicationSets (`gitops/*.yaml` and `gitops/rhacm/*.yaml`) and the wildcard in overlay `lab-apimanager` before sync.
