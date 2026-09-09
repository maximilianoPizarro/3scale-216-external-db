# Tested versions

Values below reflect a **lab migration** on AWS. Replace placeholders in overlays before applying manifests. No sandbox hostnames or EFS IDs are committed to this repository.

## Environment

| Layer | Tested value |
|-------|--------------|
| **OpenShift** | 4.19 on **AWS, self-managed** (IPI; not ROSA-managed databases) |
| **3scale source** | 2.15.5 — CSV `0.12.5`, channel `threescale-2.15` |
| **3scale target** | 2.16.4 — CSV `0.13.4`, channel `threescale-2.16` |
| **PostgreSQL** | 15 — `registry.redhat.io/rhel9/postgresql-15` |
| **Redis** | 7 — `registry.redhat.io/rhel9/redis-7` (system + backend) |

## Storage

| Use case | StorageClass | Access mode |
|----------|--------------|-------------|
| External PostgreSQL / Redis PVCs | `gp3-csi` | ReadWriteOnce |
| `system-storage` (3scale file storage) | `efs-sc` (EFS CSI driver) | ReadWriteMany |

On AWS lab clusters where the default block storage is RWO only, **EFS CSI** is required for the `system-storage` PVC. See [Install 3scale 2.15 (lab)](install-lab.md).

## Supported matrix (reference)

Always confirm against [Supported Configurations](https://access.redhat.com/articles/2798521). For 3scale 2.16:

- OpenShift: 4.14, 4.16–4.19 (4.20+ in later 2.16 micro releases)
- PostgreSQL: 14, 15 (system DB preflight requires ≥ 15.0)
- Redis: 7.2 (two instances)

Testing on OpenShift 4.19 validates the 2.16 path even when production runs an earlier supported minor. Upgrade OpenShift **after** the 3scale migration, not in the same maintenance window.
