# Instalar con un Pattern CR

Este repositorio es un [Validated Pattern](https://validatedpatterns.io/). El Validated Patterns Operator instala OpenShift GitOps y aplica los custom resources de este repo. Un recurso `Pattern` elige el escenario. Los hostnames del clúster no van en git: el operador fija `global.localClusterDomain`.

Dos escenarios. No mezclar sus archivos de values.

| Escenario | Clúster | Pattern CR | Qué instala |
|-----------|---------|------------|-------------|
| Un nodo, 2.16 | Un nodo, sin almacenamiento ReadWriteMany | [hub-216-singlenode.yaml](https://github.com/maximilianoPizarro/3scale-216-external-db/blob/main/examples/pattern-cr/hub-216-singlenode.yaml) | Canal `threescale-2.16`, PostgreSQL 15 y Redis 7 externos, Vault, External Secrets. `system-storage` usa `gp3-csi`. Recrear ese PVC como ReadWriteOnce. |
| Migración 2.15 a 2.16 | OpenShift con canal `threescale-2.15` y una clase ReadWriteMany | [hub-215.yaml](https://github.com/maximilianoPizarro/3scale-216-external-db/blob/main/examples/pattern-cr/hub-215.yaml) | 3scale 2.15 con bases embebidas. En la ventana, `extraValueFiles` pasa a `/values-cutover.yaml`, después a `/values-215-external.yaml` tras cargar el RDB. Tras el dump fresco y la verificación de 2.15, pasa a `/values-216-external.yaml` (solo el canal). |

`targetRevision` en esos archivos es `main`.

## Qué instala cada wave

| Wave | Application | Origen |
|------|-------------|--------|
| 2 | `vault` | chart `hashicorp-vault` `0.1.*` |
| 2 | `openshift-external-secrets` | chart `openshift-external-secrets` `0.0.*` |
| 4 | `external-secrets-3scale` | `charts/all/external-secrets-3scale` |
| 5 | `external-db` | `charts/all/external-db` |
| 6 | Subscription de 3scale | `clusterGroup.subscriptions` en `values-hub.yaml` |
| 7 | `threescale-apimanager` | `charts/all/threescale-apimanager` |

Los CR de Subscription los renderiza el chart clustergroup a partir de `values-hub.yaml`. Este repo no copia CRDs de operadores.

Las imágenes de PostgreSQL y Redis están ancladas en `values-global.yaml`. Ver [Anclar digest de imágenes](image-digests.es.md).

## 1. Instalar el Validated Patterns Operator

Paquete `patterns-operator` en OperatorHub, canal `fast`, namespace `openshift-operators`.

```bash
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: patterns-operator
  namespace: openshift-operators
spec:
  channel: fast
  installPlanApproval: Automatic
  name: patterns-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF
oc get csv -n openshift-operators | grep patterns-operator
```

Esperar el CSV en `Succeeded`.

## 2. Aplicar un Pattern CR

=== "Un nodo, 2.16"

    ```bash
    oc apply -f examples/pattern-cr/hub-216-singlenode.yaml
    ```

=== "Migración 2.15"

    ```bash
    oc apply -f examples/pattern-cr/hub-215.yaml
    ```

Copiar `values-secret.yaml.template` a `~/values-secret-3scale-216-external-db.yaml` y cargarlo. Eso escribe las tres passwords en Vault. No commitear el archivo relleno.

```bash
./pattern.sh make load-secrets
```

`./pattern.sh make install` despliega el patrón y carga los secretos en un paso, si hay podman. El `oc apply` del Pattern CR no carga secretos por sí solo.

## 3. Ver las applications

```bash
oc get applications -n vp-gitops
oc get csv -n 3scale
oc get csv -n external-secrets-operator
oc get pods -n vault
```

En el escenario 2.16, los Deployments de bases deben mostrar las imágenes `@sha256:` de `values-global.yaml`, y los ExternalSecret deben estar `SecretSynced`.

Una Application hija en `ComparisonError` que marca una IP vieja de repo-server se recupera con un refresh duro. El repo-server actual tiene que estar Ready:

```bash
oc annotate application -n 3scale-216-external-db-hub --all argocd.argoproj.io/refresh=hard --overwrite
```

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc get externalsecret -A
```

Entrar a Vault y ver los secretos con los comandos de [Rotación de credenciales](credential-rotation.es.md).

## Siguiente

- [Secuencia de migración](sequence.es.md) para el corte desde 2.15
- [Operación día 2](day-2.es.md)
- [Rotación de credenciales](credential-rotation.es.md)
