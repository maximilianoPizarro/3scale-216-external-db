# Migration sequence

Linux/bash steps. Aligns with `docs/runbooks/00-secuencia-y-matriz.md` in the repository.

## Order of operations

1. **Install 3scale 2.15** on a test cluster — operator + APIManager with embedded databases ([Install 3scale 2.15 (lab)](install-lab.md)).
2. **Confirm the matrix**: OpenShift version supported by both 2.15 and 2.16; latest CSV on channel `threescale-2.15`.
3. **Snapshot / backup** PVCs and secrets (`system-database`, `system-redis`, `backend-redis`).
4. **Maintenance window**: scale the 3scale operator and components to 0 **except** the database being dumped.
5. **Externalize PostgreSQL** 10 → 15 in-cluster ([Externalize PostgreSQL](externalize-postgresql.md)).
6. **Externalize Redis** 6 → 7 in-cluster ([Externalize Redis](externalize-redis.md)).
7. Set `spec.externalComponents` on the APIManager (done in the PostgreSQL and Redis runbooks).
8. **Restore replicas**, validate Admin Portal, Developer Portal, and APIcast.
9. **Upgrade operator** to channel `threescale-2.16` ([Upgrade operator to 2.16](upgrade-216.md)).
10. **Upgrade OpenShift** afterwards, if needed, per [Supported Configurations](https://access.redhat.com/articles/2798521).

!!! warning "Do not combine upgrades"
    Do not run the 3scale upgrade and the OpenShift upgrade in the same maintenance window.

## Lab vs production overlays

| Overlay | StorageClass | Use |
|---------|--------------|-----|
| `lab` / `lab-persist` | `gp3-csi` (example) | Test clusters |
| `prod` / `prod-persist` | Cluster default | Production-like |

The 3scale procedure is the same; only storage defaults differ.

## Deployment options

=== "GitOps (recommended)"

    ```bash
    # Phase 1: operator 2.15 + APIManager
    oc apply -k gitops/
    oc apply -k gitops/rhacm/              # managed cluster via ACM hub

    # Phase 2: external DBs (create system-database secret in 3scale-db first)
    oc apply -k gitops/external-db
    oc apply -k gitops/rhacm/external-db
    ```

=== "Kustomize (no Argo CD)"

    ```bash
    oc apply -k kustomize/overlays/lab-operator
    oc apply -k kustomize/overlays/lab-efs
    oc apply -k kustomize/overlays/lab-apimanager
    # after dump/restore:
    oc apply -k kustomize/overlays/lab
    ```

See [GitOps and RHACM](gitops.md) for wave ordering and RHACM placement.
