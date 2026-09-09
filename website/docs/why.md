# Why this repository exists

Starting with **3scale 2.16**, the 3scale operator **stops reconciling** these embedded databases:

| Component | What changes in 2.16 |
|-----------|----------------------|
| **PostgreSQL** (system database) | The 3scale operator no longer manages it |
| **Redis** (system and backend) | The 3scale operator no longer manages it |
| **Zync database** | Can remain internal (operator-managed) |

You must **externalize** those databases **before** you upgrade the 3scale operator to 2.16.

!!! warning "Preflight requirement"
    PostgreSQL ≥ 15.0 and Redis ≥ 7.2 are required before you upgrade.
    If versions do not meet this, the 3scale operator installs but the instance upgrade does not complete.

## External ≠ off-cluster

In Red Hat documentation, *external* means the database sits **outside the 3scale installation lifecycle**. The 3scale operator no longer creates, patches, or reconciles it.

The database **can stay in-cluster**, for example in a dedicated namespace such as `3scale-db`.

This repository is **not** an RDS or off-cluster migration guide. It provides:

- **Dump and restore** runbooks (PostgreSQL 10 → 15, Redis 6 → 7)
- **Kustomize** manifests for self-managed RHSCL images in-cluster
- **GitOps** patterns (OpenShift GitOps / Argo CD and RHACM)

## What this repo does not cover

- Managed cloud databases (RDS, Azure Database, and similar)
- Redis Cluster (Red Hat does not support it for 3scale)
- Off-cluster database topology or networking design

## Next steps

- [Prerequisites](prerequisites.md)
- [Official Red Hat documentation](official-docs.md)
- [Tested versions](tested-versions.md)
- [Migration sequence](sequence.md)
- [Day 2 operations](day-2.md)
