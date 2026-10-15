# 3scale 2.15 → 2.16 migration

This page is the **Validated Pattern** guide. Version **1.0.0** in the version selector is the Kustomize and GitOps guide, with Vault and External Secrets and without a Pattern CR.

This repository is for **OpenShift administrators** and **platform SREs** who run 3scale in-cluster and must upgrade from 2.15 to 2.16. Product procedure and supported matrix: [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index).

Use it to **externalize** PostgreSQL (system) and Redis (system and backend) **in-cluster** before you upgrade the 3scale operator to **2.16**. The databases stay on OpenShift. The 3scale operator no longer manages them after you set `externalComponents`.

A lab cutover typically takes **a few hours** once the cluster and RWX storage are ready. Production duration depends on database size and the maintenance window.

!!! note "Lab-validated package"
    Versions and storage defaults reflect a **lab migration** — see [Tested versions](tested-versions.md). Reconfirm [Supported Configurations](https://access.redhat.com/articles/2798521) and adapt placeholders (`REPLACE_*`) and StorageClasses to your cluster before you apply manifests.

This repository uses the Validated Patterns Operator. It is not a Red Hat support statement. The tested environment is AWS: OpenShift 4.19 for the 2.15 to 2.16 migration, and OpenShift 4.21 with one node for a direct 2.16 install.

## What this lab is

One replica of PostgreSQL and of each Redis. There is no high availability. A node drain or an image rollout is an outage. RPO is the last dump. RTO is the time to restore that dump. A later step can move PostgreSQL to an HA operator and Redis to a managed service. This repository does not implement that step.

The lab PostgreSQL dump was 719027 bytes. That size is not a production estimate.

## What you get

| Area | Location in the repo |
|------|----------------------|
| Pattern CR and scenario values | `examples/pattern-cr/`, `values-*.yaml` |
| Helm charts (APIManager, databases, ExternalSecret) | `charts/all/` |
| Operational runbooks (clone-friendly) | `docs/runbooks/` (ES), `docs/runbooks/en/` (EN) |

## Quick path

1. [Why this repo](why.md)
2. [Prerequisites](prerequisites.md)
3. [Install with a Pattern CR](pattern-cr.md)
4. [Migration sequence](sequence.md)
5. [Credential rotation](credential-rotation.md)
6. [Day 2 operations](day-2.md) (after the cutover)

Command examples on this site assume **Linux (bash)**. For **Git Bash on Windows**, use `docs/runbooks/01-bis-externalize-postgresql-windows.md` and `docs/runbooks/02-bis-externalize-redis-windows.md` in the repository.
