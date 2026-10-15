# 3scale 2.15 → 2.16: in-cluster PostgreSQL and Redis externalization

[![OpenShift](https://img.shields.io/badge/OpenShift-4.19-blue?logo=redhat)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![Platform](https://img.shields.io/badge/AWS-self--managed-orange?logo=amazonwebservices)](https://aws.amazon.com/)
[![3scale](https://img.shields.io/badge/3scale-2.15.5%20→%202.16.4-red)](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql&logoColor=white)](https://catalog.redhat.com/software/containers/rhel9/postgresql-15)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://catalog.redhat.com/software/containers/rhel9/redis-7)
[![Storage](https://img.shields.io/badge/Storage-gp3--csi%20%2B%20EFS%20CSI-lightgrey)](website/docs/tested-versions.md)

Reusable manifests and runbooks to **externalize** PostgreSQL (system) and Redis (system + backend) **in-cluster** before upgrading the 3scale operator to **2.16**.

Starting with 2.16, the 3scale operator **stops reconciling** those embedded databases. *External* means **outside the operator lifecycle** — databases **can remain in-cluster** (this repo uses namespace `3scale-db`). Zync database can stay internal. This package covers dump/restore and a Validated Pattern, not RDS or off-cluster migration.

**Documentation site (English / Español):** [https://maximilianopizarro.github.io/3scale-216-external-db/](https://maximilianopizarro.github.io/3scale-216-external-db/)

**Official guide:** [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Validated in lab — see [tested versions](website/docs/tested-versions.md). Adapt placeholders (`REPLACE_*`) and StorageClasses to your cluster before you apply manifests. This package complements the official Red Hat guide; it does not replace it.

## How to use this repository

1. Confirm [prerequisites](website/docs/prerequisites.md) and the [Supported Configurations](https://access.redhat.com/articles/2798521) matrix for **both** 3scale 2.15 and 2.16 on your OpenShift version.
2. Install the Validated Patterns Operator and apply `examples/pattern-cr/hub-215.yaml` ([Pattern CR](website/docs/pattern-cr.md)). The apps domain is injected. Do not commit it.
3. Externalize PostgreSQL and Redis in-cluster (runbooks `01` and `02`). During the window set `extraValueFiles` to `/values-cutover.yaml`.
4. After portal checks, set `extraValueFiles` to `/values-216-external.yaml` (channel 2.16, Redis persist, credential rotation in runbook `09`).

Full sequence: [documentation site — Migration sequence](https://maximilianopizarro.github.io/3scale-216-external-db/sequence/).

## Repository layout

| Path | Description |
|------|-------------|
| [website/](website/) | MkDocs Material site (EN default, ES at `/es/`) |
| [docs/runbooks/](docs/runbooks/) | Operational runbooks (Spanish, clone-friendly) |
| [docs/runbooks/en/](docs/runbooks/en/) | Operational runbooks (English, clone-friendly) |
| [docs/faq-externalizacion.md](docs/faq-externalizacion.md) | Logs, PVC, images, operations FAQ |
| [examples/pattern-cr/](examples/pattern-cr/) | Pattern custom resources |
| [charts/all/](charts/all/) | APIManager, external databases, ExternalSecret |
| [values-global.yaml](values-global.yaml) | Image digests and Vault paths |

## Quick start (Linux)

Requires channel `threescale-2.15` and a ReadWriteMany StorageClass named `efs-sc`. A one-node cluster without that channel uses `examples/pattern-cr/hub-216-singlenode.yaml` instead. That file is not a 2.15 migration.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

Full sequence: [website — Migration sequence](https://maximilianopizarro.github.io/3scale-216-external-db/sequence/) · [docs/runbooks/00-secuencia-y-matriz.md](docs/runbooks/00-secuencia-y-matriz.md)

## Windows / Git Bash

Use Git Bash, not PowerShell:

- [docs/runbooks/01-bis-externalize-postgresql-windows.md](docs/runbooks/01-bis-externalize-postgresql-windows.md)
- [docs/runbooks/02-bis-externalize-redis-windows.md](docs/runbooks/02-bis-externalize-redis-windows.md)

## Security

Do **not** commit secrets or migration artifacts:

- `*-secret.yaml`, `values-secret.yaml`, `pattern-vault.init`, `vault.init`
- `*.backup`, `*.rdb`
- `.env`

These paths are listed in [.gitignore](.gitignore).

---

# Español

[![OpenShift](https://img.shields.io/badge/OpenShift-4.19-blue?logo=redhat)](https://www.redhat.com/es/technologies/cloud-computing/openshift)
[![Plataforma](https://img.shields.io/badge/AWS-self--managed-orange?logo=amazonwebservices)](https://aws.amazon.com/)
[![3scale](https://img.shields.io/badge/3scale-2.15.5%20→%202.16.4-red)](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Paquete reutilizable para **externalizar** PostgreSQL (system) y Redis (system + backend) **in-cluster** antes de actualizar el operador 3scale a **2.16**.

A partir de 2.16, el operador 3scale **deja de reconciliar** esas bases embebidas. *External* significa **fuera del ciclo de vida del operador** — las bases **pueden seguir in-cluster** (este repo usa el namespace `3scale-db`). Zync puede quedar interna. Este paquete cubre dump/restore y un Validated Pattern, no RDS ni migración off-cluster.

**Sitio de documentación (inglés / español):** [https://maximilianopizarro.github.io/3scale-216-external-db/es/](https://maximilianopizarro.github.io/3scale-216-external-db/es/)

**Guía oficial:** [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Validado en laboratorio — ver [versiones probadas](website/docs/tested-versions.es.md). Adaptar placeholders (`REPLACE_*`) y StorageClasses al cluster antes de aplicar manifiestos. Este paquete complementa la guía oficial de Red Hat; no la reemplaza.

## Cómo usar este repositorio

1. Confirmar [requisitos previos](website/docs/prerequisites.es.md) y la matriz [Supported Configurations](https://access.redhat.com/articles/2798521) para **2.15 y 2.16** en la versión de OpenShift del cluster.
2. Instalar el Validated Patterns Operator y aplicar `examples/pattern-cr/hub-215.yaml` ([Pattern CR](website/docs/pattern-cr.es.md)). El dominio de apps lo inyecta el operador. No commitearlo.
3. Externalizar PostgreSQL y Redis in-cluster (runbooks `01` y `02`). En la ventana, `extraValueFiles` pasa a `/values-cutover.yaml`.
4. Tras revisar los portales, `extraValueFiles` pasa a `/values-216-external.yaml` (canal 2.16, Redis persistente, rotación en el runbook `09`).

Secuencia completa: [sitio — Secuencia de migración](https://maximilianopizarro.github.io/3scale-216-external-db/es/sequence/).

## Contenido del repositorio

| Ruta | Descripción |
|------|-------------|
| [website/](website/) | Sitio MkDocs Material (EN por defecto, ES en `/es/`) |
| [docs/runbooks/](docs/runbooks/) | Runbooks operativos (español) |
| [docs/runbooks/en/](docs/runbooks/en/) | Runbooks operativos (inglés) |
| [docs/faq-externalizacion.md](docs/faq-externalizacion.md) | FAQ: logs, PVC, imágenes |
| [examples/pattern-cr/](examples/pattern-cr/) | Pattern custom resources |
| [charts/all/](charts/all/) | APIManager, bases externas, ExternalSecret |
| [values-global.yaml](values-global.yaml) | Digest de imágenes y paths de Vault |

## Inicio rápido (Linux)

Hace falta el canal `threescale-2.15` y una StorageClass ReadWriteMany llamada `efs-sc`. Un cluster de un solo nodo sin ese canal usa `examples/pattern-cr/hub-216-singlenode.yaml`. Ese archivo no es una migración 2.15.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

Secuencia completa: [sitio — Secuencia de migración](https://maximilianopizarro.github.io/3scale-216-external-db/es/sequence/) · [docs/runbooks/00-secuencia-y-matriz.md](docs/runbooks/00-secuencia-y-matriz.md)

## Windows / Git Bash

Usar Git Bash, no PowerShell:

- [docs/runbooks/01-bis-externalize-postgresql-windows.md](docs/runbooks/01-bis-externalize-postgresql-windows.md)
- [docs/runbooks/02-bis-externalize-redis-windows.md](docs/runbooks/02-bis-externalize-redis-windows.md)

## Seguridad

**No** commitear secrets ni artefactos de migración: `*-secret.yaml`, `values-secret.yaml`, `pattern-vault.init`, `vault.init`, `*.backup`, `*.rdb`, `.env` (ver [.gitignore](.gitignore)).
