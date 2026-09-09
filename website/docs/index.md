# 3scale 2.15 → 2.16 migration

This repository is for **OpenShift administrators** and **platform SREs** who run 3scale in-cluster and must upgrade from 2.15 to 2.16. Product procedure and supported matrix: [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index).

Use it to **externalize** PostgreSQL (system) and Redis (system and backend) **in-cluster** before you upgrade the 3scale operator to **2.16**. The databases stay on OpenShift. The 3scale operator no longer manages them after you set `externalComponents`.

A lab cutover typically takes **a few hours** once the cluster and RWX storage are ready. Production duration depends on database size and the maintenance window.

## What you get

| Area | Location in the repo |
|------|----------------------|
| Kustomize bases and overlays | `kustomize/` |
| Operational runbooks (Spanish, clone-friendly) | `docs/runbooks/` |
| OpenShift GitOps / Argo CD | `gitops/` |
| RHACM hub patterns | `gitops/rhacm/` |

## Quick path

1. [Why this repo](why.md)
2. [Prerequisites](prerequisites.md)
3. [Official Red Hat documentation](official-docs.md)
4. [Migration sequence](sequence.md)
5. [Tested versions](tested-versions.md)
6. [Day 2 operations](day-2.md) (after the cutover)

Command examples on this site assume **Linux (bash)**. For **Git Bash on Windows**, use `docs/runbooks/01-bis-externalize-postgresql-windows.md` and `docs/runbooks/02-bis-externalize-redis-windows.md` in the repository.
