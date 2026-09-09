# GitOps con RHACM (escenario PUSH)

Alternativa al GitOps in-cluster. El hub de [Red Hat Advanced Cluster Management](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes) selecciona clusters y el Argo CD del hub empuja manifiestos.

Misma cadena que [Hybrid Mesh Platform](https://maximilianopizarro.github.io/hybrid-mesh-platform/validatedpatterns-docs/deploy-acm-gitops.html): `Placement` → `PlacementDecision` → `GitOpsCluster` → ApplicationSet `clusterDecisionResource`.

Fases (igual que in-cluster): primero operador 2.15, después BDD en `3scale-db`.

No aplicar `gitops/` y `gitops/rhacm/` contra el mismo destino.

## Cadena

```
ManagedCluster (label threescale-external-db=true)
  → Placement threescale-external-db-placement
  → GitOpsCluster
  → ApplicationSet threescale-operator-acm
       → Application <cluster>-threescale-operator
            path: kustomize/overlays/lab-operator
            destination.namespace: 3scale
  → ApplicationSet threescale-external-db-acm   # gitops/rhacm/external-db
       → Application <cluster>-threescale-external-db
            path: kustomize/overlays/prod
            destination.namespace: 3scale-db
```

El APIManager no se hace PUSH (hay que fijar `wildcardDomain` en `kustomize/overlays/lab-apimanager` y aplicarlo a mano o con el ApplicationSet in-cluster de operador).

| Wave | Recurso |
|------|---------|
| 0 | Role/RoleBinding PlacementDecision |
| 1 | ManagedClusterSetBinding `global` |
| 2 | Placement + ConfigMap del generador |
| 3 | GitOpsCluster |
| 4 | ApplicationSets |

## Requisitos

- ACM y OpenShift GitOps en el **hub**
- ManagedClusterSet `global`
- `REPLACE_REPO_URL` en `gitops/rhacm/applicationset-threescale-operator-acm.yaml` y `gitops/rhacm/external-db/applicationset-threescale-external-db-acm.yaml`
- Label:

```bash
oc label managedcluster <cluster> threescale-external-db=true
```

## Aplicar (hub)

```bash
oc apply -k gitops/rhacm/
# cuando 3scale 2.15 esté sano y toque externalizar:
oc apply -k gitops/rhacm/external-db
```

## Verificar

```bash
oc get placementdecisions.cluster.open-cluster-management.io -n openshift-gitops \
  -l cluster.open-cluster-management.io/placement=threescale-external-db-placement
oc get gitopscluster -n openshift-gitops threescale-external-db-gitops
oc get applicationset -n openshift-gitops
oc get applications -n openshift-gitops | grep threescale
```

Si no hay Applications: cluster Available con el label; binding `global`; GitOpsCluster con el cluster en Argo CD; Role `applicationset-placementdecisions`.

## Persistencia Redis

En `gitops/rhacm/external-db/applicationset-threescale-external-db-acm.yaml`, `path: kustomize/overlays/prod-persist` (lab: `kustomize/overlays/lab` / `lab-persist`). `prune: false`.
