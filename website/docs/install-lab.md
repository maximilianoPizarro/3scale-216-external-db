# Install 3scale 2.15 (lab)

Install the **2.15 3scale operator** and an APIManager with **embedded** PostgreSQL and Redis before you externalize. The database overlay does **not** install the 3scale operator.

Complete [Prerequisites](prerequisites.md) first.

## 1. Install the 3scale operator (OLM)

```bash
oc apply -k kustomize/overlays/lab-operator
oc -n 3scale get csv,subscription,pods
```

Wait for CSV `Succeeded` and pod `threescale-operator-controller-manager-v2`.

Catalog: `redhat-operators` / `openshift-marketplace`. On disconnected clusters, change `spec.source` on the Subscription.

## 2. Provide RWX volume for `system-storage`

3scale requires **ReadWriteMany** for PVC `system-storage`. On AWS, `gp3-csi` is RWO. The PVC stays Pending (`Volume capabilities not supported`).

On AWS lab clusters: create an EFS filesystem in the cluster VPC (mount targets + TCP 2049 from node security groups). Then apply the EFS CSI overlay:

```bash
# Set fileSystemId in kustomize/overlays/lab-efs/kustomization.yaml
oc apply -k kustomize/overlays/lab-efs
oc -n openshift-cluster-csi-drivers get csv,pods | grep efs
oc get sc efs-sc
```

Details: `kustomize/overlays/lab-efs/README.md`. On other clouds, replace `efs-sc` with an equivalent RWX StorageClass.

## 3. Deploy APIManager 2.15 (embedded PostgreSQL)

Set the apps domain in `kustomize/overlays/lab-apimanager/kustomization.yaml` (`REPLACE_WILDCARD_DOMAIN`, for example `apps.cluster.example.com`). The overlay already points `fileStorage` to `efs-sc`.

```bash
oc apply -k kustomize/overlays/lab-apimanager
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

```bash
oc apply -k kustomize/overlays/operator-216
```

GitOps phase 1 (3scale operator + APIManager, not databases):

```bash
oc apply -k gitops/
# ACM hub:
oc apply -k gitops/rhacm/
```

Set `REPLACE_REPO_URL` in ApplicationSets (`gitops/*.yaml`, `gitops/rhacm/*.yaml`) and the wildcard in overlay `lab-apimanager` before sync.
