# 3scale 2.15 → 2.16: in-cluster PostgreSQL and Redis externalization

[![OpenShift](https://img.shields.io/badge/OpenShift-4.19-blue?logo=redhat)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![Platform](https://img.shields.io/badge/AWS-self--managed-orange?logo=amazonwebservices)](https://aws.amazon.com/)
[![3scale](https://img.shields.io/badge/3scale-2.15.5%20→%202.16.4-red)](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql&logoColor=white)](https://catalog.redhat.com/software/containers/rhel9/postgresql-15)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://catalog.redhat.com/software/containers/rhel9/redis-7)
[![Storage](https://img.shields.io/badge/Storage-gp3--csi%20%2B%20EFS%20CSI-lightgrey)](website/docs/tested-versions.md)

Reusable manifests and runbooks to **externalize** PostgreSQL (system) and Redis (system + backend) **in-cluster** before upgrading the 3scale operator to **2.16**.

Starting with 2.16, the 3scale operator **stops reconciling** those embedded databases. *External* means **outside the operator lifecycle** — databases **can remain in-cluster** (this repo uses namespace `3scale-db`). Zync database can stay internal. This package covers dump/restore + Kustomize/GitOps, not RDS or off-cluster migration.

**Documentation site (English / Español):** [https://maximilianopizarro.github.io/3scale-216-external-db/](https://maximilianopizarro.github.io/3scale-216-external-db/)

**Official guide:** [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Validated in lab — see [tested versions](website/docs/tested-versions.md). Adapt placeholders (`REPLACE_*`) and StorageClasses to your cluster before you apply manifests. This package complements the official Red Hat guide; it does not replace it.

## How to use this repository

1. Confirm [prerequisites](website/docs/prerequisites.md) and the [Supported Configurations](https://access.redhat.com/articles/2798521) matrix for **both** 3scale 2.15 and 2.16 on your OpenShift version.
2. Edit placeholders: `REPLACE_WILDCARD_DOMAIN`, `REPLACE_EFS_FILESYSTEM_ID`, and `REPLACE_REPO_URL` (GitOps).
3. Install 3scale **2.15** with embedded databases and validate portals ([install lab](website/docs/install-lab.md) or runbook `05`).
4. Externalize PostgreSQL and Redis in-cluster (runbooks `01` and `02`; Git Bash: `01-bis` / `02-bis`).
5. Upgrade the operator to **2.16**, then operate day 2 in `3scale-db` (runbooks `03`, `06`; rollback: `07`).

Full sequence: [documentation site — Migration sequence](https://maximilianopizarro.github.io/3scale-216-external-db/sequence/).

## Repository layout

| Path | Description |
|------|-------------|
| [website/](website/) | MkDocs Material site (EN default, ES at `/es/`) |
| [docs/runbooks/](docs/runbooks/) | Operational runbooks (Spanish, clone-friendly) |
| [docs/runbooks/en/](docs/runbooks/en/) | Operational runbooks (English, clone-friendly) |
| [docs/faq-externalizacion.md](docs/faq-externalizacion.md) | Logs, PVC, images, operations FAQ |
| [kustomize/](kustomize/) | Operator OLM, APIManager, external DB manifests |
| [gitops/](gitops/) | Phase 1: operator. [gitops/external-db](gitops/external-db/): phase 2 DBs |
| [gitops/rhacm/](gitops/rhacm/) | RHACM hub patterns |

## Quick start (Linux)

Edit placeholders in overlays (`REPLACE_WILDCARD_DOMAIN`, `REPLACE_EFS_FILESYSTEM_ID`, `REPLACE_REPO_URL` for GitOps) before applying.

```bash
# 1. Operator 2.15
oc apply -k kustomize/overlays/lab-operator

# 2. RWX for system-storage (EFS CSI on AWS lab)
oc apply -k kustomize/overlays/lab-efs

# 3. APIManager with embedded PostgreSQL
oc apply -k kustomize/overlays/lab-apimanager

# 4. After dump/restore (runbooks 01 and 02): external databases
oc apply -k kustomize/overlays/lab

# 5. After validation: operator channel 2.16
oc apply -k kustomize/overlays/operator-216
```

Full sequence: [website — Migration sequence](https://maximilianopizarro.github.io/3scale-216-external-db/sequence/) · [docs/runbooks/00-secuencia-y-matriz.md](docs/runbooks/00-secuencia-y-matriz.md)

GitOps: `oc apply -k gitops/` (phase 1) then `oc apply -k gitops/external-db` (phase 2). See [gitops/README.md](gitops/README.md).

## Windows / Git Bash

Use Git Bash, not PowerShell:

- [docs/runbooks/01-bis-externalize-postgresql-windows.md](docs/runbooks/01-bis-externalize-postgresql-windows.md)
- [docs/runbooks/02-bis-externalize-redis-windows.md](docs/runbooks/02-bis-externalize-redis-windows.md)

## Security

Do **not** commit secrets or migration artifacts:

- `*-secret.yaml`
- `*.backup`, `*.rdb`
- `.env`

These paths are listed in [.gitignore](.gitignore).

---

# Español

[![OpenShift](https://img.shields.io/badge/OpenShift-4.19-blue?logo=redhat)](https://www.redhat.com/es/technologies/cloud-computing/openshift)
[![Plataforma](https://img.shields.io/badge/AWS-self--managed-orange?logo=amazonwebservices)](https://aws.amazon.com/)
[![3scale](https://img.shields.io/badge/3scale-2.15.5%20→%202.16.4-red)](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Paquete reutilizable para **externalizar** PostgreSQL (system) y Redis (system + backend) **in-cluster** antes de actualizar el operador 3scale a **2.16**.

A partir de 2.16, el operador 3scale **deja de reconciliar** esas bases embebidas. *External* significa **fuera del ciclo de vida del operador** — las bases **pueden seguir in-cluster** (este repo usa el namespace `3scale-db`). Zync puede quedar interna. Este paquete cubre dump/restore + Kustomize/GitOps, no RDS ni migración off-cluster.

**Sitio de documentación (inglés / español):** [https://maximilianopizarro.github.io/3scale-216-external-db/es/](https://maximilianopizarro.github.io/3scale-216-external-db/es/)

**Guía oficial:** [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Validado en laboratorio — ver [versiones probadas](website/docs/tested-versions.es.md). Adaptar placeholders (`REPLACE_*`) y StorageClasses al cluster antes de aplicar manifiestos. Este paquete complementa la guía oficial de Red Hat; no la reemplaza.

## Cómo usar este repositorio

1. Confirmar [requisitos previos](website/docs/prerequisites.es.md) y la matriz [Supported Configurations](https://access.redhat.com/articles/2798521) para **2.15 y 2.16** en la versión de OpenShift del cluster.
2. Editar placeholders: `REPLACE_WILDCARD_DOMAIN`, `REPLACE_EFS_FILESYSTEM_ID` y `REPLACE_REPO_URL` (GitOps).
3. Instalar 3scale **2.15** con bases embebidas y validar portales ([instalar lab](website/docs/install-lab.es.md) o runbook `05`).
4. Externalizar PostgreSQL y Redis in-cluster (runbooks `01` y `02`; Git Bash: `01-bis` / `02-bis`).
5. Actualizar el operador a **2.16** y operar el día 2 en `3scale-db` (runbooks `03`, `06`; rollback: `07`).

Secuencia completa: [sitio — Secuencia de migración](https://maximilianopizarro.github.io/3scale-216-external-db/es/sequence/).

## Contenido del repositorio

| Ruta | Descripción |
|------|-------------|
| [website/](website/) | Sitio MkDocs Material (EN por defecto, ES en `/es/`) |
| [docs/runbooks/](docs/runbooks/) | Runbooks operativos (español) |
| [docs/runbooks/en/](docs/runbooks/en/) | Runbooks operativos (inglés) |
| [docs/faq-externalizacion.md](docs/faq-externalizacion.md) | FAQ: logs, PVC, imágenes |
| [kustomize/](kustomize/) | Operador OLM, APIManager, manifiestos BDD |
| [gitops/](gitops/) | Fase 1: operador. [gitops/external-db](gitops/external-db/): fase 2 BDD |
| [gitops/rhacm/](gitops/rhacm/) | Patrones RHACM (hub) |

## Inicio rápido (Linux)

Editar placeholders en overlays (`REPLACE_WILDCARD_DOMAIN`, `REPLACE_EFS_FILESYSTEM_ID`, `REPLACE_REPO_URL` en GitOps) antes de aplicar.

```bash
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs
oc apply -k kustomize/overlays/lab-apimanager
# tras dump/restore (runbooks 01 y 02):
oc apply -k kustomize/overlays/lab
# tras validar:
oc apply -k kustomize/overlays/operator-216
```

Secuencia completa: [sitio — Secuencia de migración](https://maximilianopizarro.github.io/3scale-216-external-db/es/sequence/) · [docs/runbooks/00-secuencia-y-matriz.md](docs/runbooks/00-secuencia-y-matriz.md)

GitOps: `oc apply -k gitops/` (fase 1) y luego `oc apply -k gitops/external-db` (fase 2). Ver [gitops/README.md](gitops/README.md).

## Windows / Git Bash

Usar Git Bash, no PowerShell:

- [docs/runbooks/01-bis-externalize-postgresql-windows.md](docs/runbooks/01-bis-externalize-postgresql-windows.md)
- [docs/runbooks/02-bis-externalize-redis-windows.md](docs/runbooks/02-bis-externalize-redis-windows.md)

## Seguridad

**No** commitear secrets ni artefactos de migración: `*-secret.yaml`, `*.backup`, `*.rdb`, `.env` (ver [.gitignore](.gitignore)).
