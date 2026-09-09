# GitOps (OpenShift GitOps / Argo CD)

Dos fases. **No** aplicar operador y BDD en el mismo momento en un cluster vacío: el APIManager 2.15 debe crear PostgreSQL/Redis embebidos primero; las instancias de `3scale-db` entran en la ventana de externalización.

Sustituir `REPLACE_REPO_URL` en:

- `gitops/applicationset-threescale-operator.yaml`
- `gitops/external-db/applicationset-threescale-external-db.yaml`
- `gitops/rhacm/applicationset-threescale-operator-acm.yaml`
- `gitops/rhacm/external-db/applicationset-threescale-external-db-acm.yaml`

Y `REPLACE_WILDCARD_DOMAIN` en `kustomize/overlays/lab-apimanager/kustomization.yaml`.

Antes del APIManager hace falta una StorageClass **RWX**. En AWS de laboratorio: crear el filesystem EFS, poner `fileSystemId` en `kustomize/overlays/lab-efs` y aplicar ese overlay (cluster-scoped; no va en este ApplicationSet).

## Fase 1 — operador 2.15 + APIManager

```bash
oc apply -k gitops/
```

| Wave | Application | Path |
|------|-------------|------|
| 0 | `threescale-operator` | `kustomize/overlays/lab-operator` |
| 5 | `threescale-apimanager` | `kustomize/overlays/lab-apimanager` |

Destino: namespace `3scale`. `SkipDryRunOnMissingResource` cubre el CRD del APIManager hasta que el CSV esté listo.

## Fase 2 — PostgreSQL 15 + Redis 7 (después de dump)

Crear antes el secret `system-database` en `3scale-db` (claves `DB_USER` y `DB_PASSWORD`). Plantilla: `kustomize/bases/postgresql/secret.example.yaml`.

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

Tras el restore de Redis, en el ApplicationSet de BDD cambiar `redis-config.path` a `kustomize/bases/redis-config-persist`.

## RHACM (hub)

Misma separación:

```bash
oc apply -k gitops/rhacm/              # Placement + operador PUSH
oc apply -k gitops/rhacm/external-db   # overlay prod → 3scale-db en el managed cluster
```

No mezclar in-cluster (`gitops/`) y RHACM contra el mismo destino.

## Fallback sin Argo CD

```bash
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs
oc apply -k kustomize/overlays/lab-apimanager
# más tarde:
oc apply -k kustomize/overlays/lab
```
