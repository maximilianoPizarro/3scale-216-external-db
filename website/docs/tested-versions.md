# Tested versions

Values below reflect a **lab migration** on AWS. Replace placeholders in overlays before you apply manifests. This repository does not commit sandbox hostnames or EFS IDs.

Product matrix: [Supported Configurations](https://access.redhat.com/articles/2798521).

!!! note "Re-check the matrix before production"
    Red Hat updates [Supported Configurations](https://access.redhat.com/articles/2798521) with product micro releases. Confirm OpenShift, PostgreSQL, and Redis versions for **both** 3scale 2.15 and 2.16 on your target cluster before you schedule the maintenance window. The lab values below are a snapshot, not a substitute for the live article.

## Environment

| Layer | Tested value |
|-------|--------------|
| **OpenShift** | 4.19 on **AWS** for the migration. 4.21 single-node for a direct 2.16 install. |
| **3scale source** | 2.15.5 — CSV `0.12.5`, channel `threescale-2.15` |
| **3scale target** | 2.16.4 — CSV `0.13.4`, channel `threescale-2.16` |
| **PostgreSQL** | 15 — `registry.redhat.io/rhel9/postgresql-15` |
| **Redis** | 7 — `registry.redhat.io/rhel9/redis-7` (system + backend) |
| **Install path** | Validated Pattern. Digests in `values-global.yaml`. See [Pin image digests](image-digests.md). |

A single-node OpenShift 4.21 install that uses `values-216-singlenode.yaml` is a direct 2.16 install. It is not this 2.15 migration. That scenario uses `gp3-csi` for `system-storage` because the node count is one.

## Storage

| Use case | StorageClass | Access mode |
|----------|--------------|-------------|
| External PostgreSQL / Redis PVCs | `gp3-csi` | ReadWriteOnce |
| `system-storage` (3scale file storage) | `efs-sc` (EFS CSI driver) | ReadWriteMany |

On AWS lab clusters the ReadWriteMany path is **EFS CSI** and class `efs-sc`. Without EFS, Local Storage Operator can publish a class with the same name. The local PV is ReadWriteOnce, so recreate `system-storage` as ReadWriteOnce. See [Install 3scale 2.15 (lab)](install-lab.md). Do not run EFS and that LocalVolume at the same time.

This repo pins PostgreSQL 15. The operator preflight requires ≥ 15.0, so PostgreSQL 14 is outside this procedure even when the product matrix lists it.

## Supported matrix (reference)

For 3scale 2.16, Red Hat documents:

- OpenShift: 4.14, 4.16–4.19 (4.20+ in later 2.16 micro releases)
- PostgreSQL: 14, 15 (system DB preflight requires ≥ 15.0)
- Redis: 7.2 (two instances)

Testing on OpenShift 4.19 validates the 2.16 path even when production runs an earlier supported minor. Upgrade OpenShift **after** the 3scale migration. Do not combine those upgrades in one maintenance window.
