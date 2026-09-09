# GitOps and RHACM

Two phases. **Do not** apply the operator and external databases at the same time on an empty cluster: APIManager 2.15 must create embedded PostgreSQL/Redis first; `3scale-db` resources enter during the externalization window.

Replace placeholders before sync:

- `REPLACE_REPO_URL` in ApplicationSets under `gitops/` and `gitops/rhacm/`
- `REPLACE_WILDCARD_DOMAIN` in `kustomize/overlays/lab-apimanager/kustomization.yaml`
- `REPLACE_EFS_FILESYSTEM_ID` in `kustomize/overlays/lab-efs/kustomization.yaml`

Before APIManager, you need an **RWX** StorageClass. On AWS lab: create the EFS filesystem, set `fileSystemId` in `kustomize/overlays/lab-efs`, and apply that overlay (cluster-scoped; not in the ApplicationSet).

## Phase 1 — operator 2.15 + APIManager

```bash
oc apply -k gitops/
```

| Wave | Application | Path |
|------|-------------|------|
| 0 | `threescale-operator` | `kustomize/overlays/lab-operator` |
| 5 | `threescale-apimanager` | `kustomize/overlays/lab-apimanager` |

Destination: namespace `3scale`. `SkipDryRunOnMissingResource` covers the APIManager CRD until the CSV is ready.

## Phase 2 — PostgreSQL 15 + Redis 7 (after dump)

Create secret `system-database` in `3scale-db` first (`DB_USER`, `DB_PASSWORD`). Template: `kustomize/bases/postgresql/secret.example.yaml`.

```bash
oc apply -k gitops/external-db
```

| Wave | Application | Path |
|------|-------------|------|
| 0 | `threescale-ext-namespace` | `kustomize/bases/namespace` |
| 1 | `threescale-ext-postgresql` | `kustomize/bases/postgresql` |
| 1 | `threescale-ext-redis-config` | `kustomize/bases/redis-config-restore` |
| 2 | `threescale-ext-redis-backend` | `kustomize/bases/redis-backend` |
| 2 | `threescale-ext-redis-system` | `kustomize/bases/redis-system` |

Destination: `3scale-db`. `prune: false` to avoid deleting PVCs.

After Redis restore, change `redis-config.path` to `kustomize/bases/redis-config-persist` in the external-db ApplicationSet.

## RHACM (hub)

Same separation:

```bash
oc apply -k gitops/rhacm/              # Placement + operator PUSH
oc apply -k gitops/rhacm/external-db   # prod overlay → 3scale-db on managed cluster
```

!!! warning "Do not mix controllers"
    Do not use in-cluster GitOps (`gitops/`) and RHACM against the same destination cluster.

## Fallback without Argo CD

```bash
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs
oc apply -k kustomize/overlays/lab-apimanager
# later:
oc apply -k kustomize/overlays/lab
```
