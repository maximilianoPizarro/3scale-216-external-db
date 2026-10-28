# 3scale 2.15 → 2.16: in-cluster PostgreSQL and Redis externalization

[![OpenShift](https://img.shields.io/badge/OpenShift-4.19-blue?logo=redhat)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![Platform](https://img.shields.io/badge/AWS-self--managed-orange?logo=amazonwebservices)](https://aws.amazon.com/)
[![3scale](https://img.shields.io/badge/3scale-2.15.5%20→%202.16.4-red)](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql&logoColor=white)](https://catalog.redhat.com/software/containers/rhel9/postgresql-15)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://catalog.redhat.com/software/containers/rhel9/redis-7)
[![Storage](https://img.shields.io/badge/Storage-gp3--csi%20%2B%20EFS%20CSI-lightgrey)](website/docs/tested-versions.md)

Reusable manifests and runbooks to **externalize** PostgreSQL (system) and Redis (system + backend) **in-cluster** before upgrading the 3scale operator to **2.16**.

Starting with 2.16, the 3scale operator **stops reconciling** those embedded databases. *External* means **outside the operator lifecycle** — databases **can remain in-cluster** (this repo uses namespace `3scale-db`). Zync database can stay internal. This package covers dump/restore, not RDS or off-cluster migration.

**Documentation:** [https://maximilianopizarro.github.io/3scale-216-external-db/](https://maximilianopizarro.github.io/3scale-216-external-db/) (English by default; Spanish from the language selector).

**Official guide:** [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index)

Validated in lab — see [tested versions](website/docs/tested-versions.md). Adapt placeholders (`REPLACE_*`) and StorageClasses to your cluster before you apply manifests. This package complements the official Red Hat guide; it does not replace it.

## Two ways to install

Use one guide on a cluster. Do not install both on the same cluster: they share the namespaces `vault`, `external-secrets`, `3scale`, and `3scale-db`, and the same `ClusterSecretStore` name.

| | Validated Pattern | Kustomize 1.0.0 |
|--|-------------------|-----------------|
| Where | This branch (`main`) | Tag [`v1.0.0`](https://github.com/maximilianoPizarro/3scale-216-external-db/releases/tag/v1.0.0) |
| Docs | [validated-pattern](https://maximilianopizarro.github.io/3scale-216-external-db/validated-pattern/) | [1.0.0](https://maximilianopizarro.github.io/3scale-216-external-db/1.0.0/) |
| Install | Validated Patterns Operator and a Pattern CR | Kustomize overlays, plus Helm for Vault |
| Secrets | Vault and External Secrets, created by the Pattern | Vault chart `hashicorp-vault` 0.1.10 and the External Secrets Operator Subscription (`stable-v1`) |
| Images | SHA-256 digests in `values-global.yaml` | Same digests, pinned on the three database Deployments |

### Validated Pattern

On this branch, install with a Pattern CR. OpenShift GitOps comes from the Validated Patterns Operator.

Two Pattern scenarios stay separate:

- **2.15 → 2.16 migration.** Needs channel `threescale-2.15` and a ReadWriteMany StorageClass named `efs-sc`. Apply `examples/pattern-cr/hub-215.yaml`. During the window, `extraValueFiles` is `/values-cutover.yaml`, then `/values-215-external.yaml` after RDB load. After the 2.15 verification, switch it to `/values-216-external.yaml` (channel only).
- **Direct 2.16 on one node**, with no `threescale-2.15` channel and no ReadWriteMany volume. Apply `examples/pattern-cr/hub-216-singlenode.yaml`. That file is not a 2.15 migration.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

Sequence: [Migration sequence](https://maximilianopizarro.github.io/3scale-216-external-db/validated-pattern/sequence/).

### Kustomize 1.0.0

Tag `v1.0.0` is the Kustomize and GitOps guide. It has no Pattern CR. Operators and the external databases come from Kustomize. Vault is the Helm chart. External Secrets is an OLM Subscription. Passwords stay outside git.

Check out that tag and follow [the 1.0.0 site](https://maximilianopizarro.github.io/3scale-216-external-db/1.0.0/). The `kustomize/` tree on `main` is not that release.

## Repository layout

| Path | Description |
|------|-------------|
| [website/](website/) | MkDocs site for the Validated Pattern (English default, Spanish under `/es/`) |
| [docs/runbooks/](docs/runbooks/) | Operational runbooks (Spanish) |
| [docs/runbooks/en/](docs/runbooks/en/) | Operational runbooks (English) |
| [docs/faq-externalizacion.md](docs/faq-externalizacion.md) | Logs, PVC, images, operations FAQ |
| [examples/pattern-cr/](examples/pattern-cr/) | Pattern custom resources |
| [charts/all/](charts/all/) | APIManager, external databases, ExternalSecret |
| [values-global.yaml](values-global.yaml) | Image digests and Vault paths |
| [kustomize/](kustomize/) | Kustomize bases and overlays; the published copy is tag `v1.0.0` |

## Security

Do **not** commit secrets or migration artifacts:

- `*-secret.yaml`, `values-secret.yaml`, `pattern-vault.init`, `vault.init`
- `*.backup`, `*.rdb`
- `.env`

These paths are listed in [.gitignore](.gitignore).
