# 3scale 2.15 → 2.16 migration

Reusable manifests and runbooks to **externalize** PostgreSQL (system) and Redis (system and backend) **inside OpenShift** before upgrading the 3scale operator to **2.16**.

All step-by-step procedures on this site assume **Linux** (bash). For **Windows / Git Bash** variants, see the [repository README](https://github.com/maximilianoPizarro/3scale-migration-216#windows--git-bash).

## What you get

| Area | Location in the repo |
|------|----------------------|
| Kustomize bases and overlays | `kustomize/` |
| Operational runbooks (Spanish, clone-friendly) | `docs/runbooks/` |
| OpenShift GitOps / Argo CD | `gitops/` |
| RHACM hub patterns | `gitops/rhacm/` |

## Quick path

1. [Why externalize databases](why.md)
2. [Official Red Hat documentation](official-docs.md)
3. [Migration sequence](sequence.md) (Linux)
4. [Tested versions](tested-versions.md)
