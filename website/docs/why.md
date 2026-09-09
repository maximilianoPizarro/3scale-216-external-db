# Why this repository exists

Starting with **3scale 2.16**, the operator **stops reconciling** these embedded databases:

| Component | What changes in 2.16 |
|-----------|----------------------|
| **PostgreSQL** (system database) | No longer managed by the operator |
| **Redis** (system and backend) | No longer managed by the operator |
| **Zync database** | Can remain internal (operator-managed) |

You must **externalize** those databases **before** upgrading the operator to 2.16. If versions do not meet the 2.16 preflight checks (PostgreSQL ≥ 15.0, Redis ≥ 7.2), the operator installs but **does not complete** the instance upgrade.

## External ≠ off-cluster

In Red Hat documentation, *external* means the database is **outside the 3scale installation lifecycle** — the operator does not create, patch, or reconcile it. The database **can stay in the same OpenShift cluster**, even in a dedicated namespace such as `3scale-db`.

This repository is **not** an RDS or off-cluster migration guide. It provides:

- **Dump and restore** runbooks (PostgreSQL 10 → 15, Redis 6 → 7)
- **Kustomize** manifests for self-managed RHSCL images in-cluster
- **GitOps** patterns (OpenShift GitOps / Argo CD and RHACM)

## What this repo does not cover

- Managed cloud databases (RDS, Azure Database, etc.)
- Redis Cluster (not supported by Red Hat for 3scale)
- Windows-specific procedures on this site — use the repository runbooks `01-bis` and `02-bis` linked from the [README](https://github.com/maximilianoPizarro/3scale-migration-216#windows--git-bash)

## Next steps

- [Official Red Hat documentation](official-docs.md)
- [Tested versions](tested-versions.md)
- [Migration sequence](sequence.md)
