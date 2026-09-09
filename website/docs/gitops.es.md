# GitOps y RHACM

Usar dos fases. **No** aplicar el operador 3scale y las bases in-cluster a la vez en un cluster vacío. El APIManager 2.15 debe crear PostgreSQL y Redis embebidos primero. Los recursos de `3scale-db` entran en la ventana de externalización.

Sustituir placeholders antes del sync:

- `REPLACE_REPO_URL` en ApplicationSets bajo `gitops/` y `gitops/rhacm/`
- `REPLACE_WILDCARD_DOMAIN` en `kustomize/overlays/lab-apimanager/kustomization.yaml`
- `REPLACE_EFS_FILESYSTEM_ID` en `kustomize/overlays/lab-efs/kustomization.yaml`

Antes del APIManager hace falta una StorageClass **RWX**. En AWS de laboratorio: crear el filesystem EFS, poner `fileSystemId` en `kustomize/overlays/lab-efs` y aplicar ese overlay (cluster-scoped; no va en el ApplicationSet).

## Fase 1 — operador 3scale 2.15 + APIManager

```bash
oc apply -k gitops/
```

| Wave | Application | Path |
|------|-------------|------|
| 0 | `threescale-operator` | `kustomize/overlays/lab-operator` |
| 5 | `threescale-apimanager` | `kustomize/overlays/lab-apimanager` |

Destino: namespace `3scale`. `SkipDryRunOnMissingResource` cubre el CRD del APIManager hasta que el CSV esté listo.

## Fase 2 — PostgreSQL 15 + Redis 7 (después del dump)

Crear antes el secret `system-database` en `3scale-db` (`DB_USER`, `DB_PASSWORD`). Plantilla: `kustomize/bases/postgresql/secret.example.yaml`.

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

Destino: `3scale-db`. `prune: false` para no borrar PVC.

Tras el restore de Redis, cambiar `redis-config.path` a `kustomize/bases/redis-config-persist` en el ApplicationSet de BDD. Dejarlo así el día 2. `selfHeal: true` revierte un edit manual del ConfigMap. Ver [Operación día 2](day-2.es.md).

## RHACM (hub)

Misma separación:

```bash
oc apply -k gitops/rhacm/              # Placement + operador 3scale PUSH
oc apply -k gitops/rhacm/external-db   # overlay prod → 3scale-db en managed cluster
```

!!! warning "No mezclar controladores"
    No usar GitOps in-cluster (`gitops/`) y RHACM contra el mismo cluster destino.

## Fallback sin Argo CD

```bash
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs
oc apply -k kustomize/overlays/lab-apimanager
# más tarde:
oc apply -k kustomize/overlays/lab
```
