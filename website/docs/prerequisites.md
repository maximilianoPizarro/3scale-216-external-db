# Prerequisites

Work through this checklist before you run any `oc apply` or dump command. Confirm versions in [Supported Configurations](https://access.redhat.com/articles/2798521) and the [2.16 migration guide](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index).

## Who this is for

- OpenShift administrators
- Platform SREs who operate 3scale in-cluster
- Cluster-admin (or equivalent) to install operators, create namespaces, and patch the APIManager

## Cluster and product versions

- OpenShift version supported by **both** 3scale 2.15 and 2.16
- 3scale on channel `threescale-2.15` (latest CSV) **before** you externalize
- Do **not** upgrade OpenShift in the same window as the 3scale upgrade

This lab was tested on OpenShift 4.19. See [Tested versions](tested-versions.md).

## Access and tooling

- `oc` logged in to the target cluster
- Pull access to `registry.redhat.io` for RHSCL images
- Linux bash for dump/restore (Git Bash on Windows: runbooks `01-bis` / `02-bis` in `docs/runbooks/`)

## Storage

- **ReadWriteMany** StorageClass for `system-storage` (EFS CSI / `efs-sc` on the AWS lab)
- **ReadWriteOnce** StorageClass for in-cluster PostgreSQL and Redis PVCs (`gp3-csi` on the AWS lab)

## Backup before the maintenance window

- Snapshot or back up PVCs (`postgresql-data`, Redis storage, `system-storage`)
- Export secrets `system-database`, `system-redis`, and `backend-redis`
- Plan a maintenance window. You will scale the 3scale operator and most 3scale components to 0 during dump and restore.

!!! warning "Preflight requirement"
    After externalization, PostgreSQL must be ≥ 15.0 and Redis ≥ 7.2. Otherwise the 3scale operator 2.16 installs but the instance upgrade does not complete.

## What you will not do in this repo

- Move databases off-cluster (RDS, Azure Database, and similar)
- Enable Redis Cluster
- Combine the 3scale upgrade and the OpenShift upgrade in one window

## Next steps

- [Official documentation](official-docs.md)
- [Migration sequence](sequence.md)
- [Install 3scale 2.15 (lab)](install-lab.md)
