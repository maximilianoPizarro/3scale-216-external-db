# Install with a Pattern CR

This repository is a [Validated Pattern](https://validatedpatterns.io/). The Validated Patterns Operator installs OpenShift GitOps and applies the custom resources in this repo. One `Pattern` resource selects the scenario. Cluster hostnames stay out of git: the operator sets `global.localClusterDomain`.

Two scenarios. Do not mix their value files.

| Scenario | Cluster | Pattern CR | What it installs |
|----------|---------|------------|------------------|
| Single-node 2.16 | One node, no ReadWriteMany storage | [hub-216-singlenode.yaml](https://github.com/maximilianoPizarro/3scale-216-external-db/blob/main/examples/pattern-cr/hub-216-singlenode.yaml) | 3scale channel `threescale-2.16`, external PostgreSQL 15 and Redis 7, Vault, External Secrets. `system-storage` uses `gp3-csi`. Recreate that PVC as ReadWriteOnce. |
| Migration 2.15 to 2.16 | OpenShift that offers channel `threescale-2.15` and a ReadWriteMany class | [hub-215.yaml](https://github.com/maximilianoPizarro/3scale-216-external-db/blob/main/examples/pattern-cr/hub-215.yaml) | 3scale 2.15 with embedded databases. During the window, point `extraValueFiles` at `/values-cutover.yaml`. After the fresh dump and the smoke test, point it at `/values-216-external.yaml`. |

`targetRevision` in those files is `main`.

## What each wave installs

| Wave | Application | Source |
|------|-------------|--------|
| 2 | `vault` | chart `hashicorp-vault` `0.1.*` |
| 2 | `openshift-external-secrets` | chart `openshift-external-secrets` `0.0.*` |
| 4 | `external-secrets-3scale` | `charts/all/external-secrets-3scale` |
| 5 | `external-db` | `charts/all/external-db` |
| 6 | 3scale Subscription | `clusterGroup.subscriptions` in `values-hub.yaml` |
| 7 | `threescale-apimanager` | `charts/all/threescale-apimanager` |

The Subscription custom resources are rendered by the clustergroup chart from `values-hub.yaml`. This repo does not vendor operator CRDs.

PostgreSQL and Redis images are pinned in `values-global.yaml`. See [Pin image digests](image-digests.md).

## 1. Install the Validated Patterns Operator

OperatorHub package `patterns-operator`, channel `fast`, namespace `openshift-operators`.

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

Wait until the CSV is `Succeeded`.

## 2. Apply one Pattern CR

=== "Single-node 2.16"

    ```bash
    oc apply -f examples/pattern-cr/hub-216-singlenode.yaml
    ```

=== "Migration 2.15"

    ```bash
    oc apply -f examples/pattern-cr/hub-215.yaml
    ```

Copy `values-secret.yaml.template` to `~/values-secret-3scale-216-external-db.yaml` and load it. That writes the three passwords into Vault. Do not commit the filled file.

```bash
./pattern.sh make load-secrets
```

`./pattern.sh make install` deploys the operator payload and loads secrets in one step, when podman is available. `oc apply` of the Pattern CR does not load secrets by itself.

## 3. Watch the applications

```bash
oc get applications -n vp-gitops
oc get csv -n 3scale
oc get csv -n external-secrets-operator
oc get pods -n vault
```

On the 2.16 scenario, the database Deployments must show the `@sha256:` images from `values-global.yaml`, and the ExternalSecrets must be `SecretSynced`.

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc get externalsecret -A
```

Log in to Vault and read the secrets with the commands on [Credential rotation](credential-rotation.md).

## Next

- [Migration sequence](sequence.md) for the 2.15 cutover
- [Day 2 operations](day-2.md)
- [Credential rotation](credential-rotation.md)
