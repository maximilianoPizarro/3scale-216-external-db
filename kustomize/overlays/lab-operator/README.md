# Operador 3scale (laboratorio)

Instala OLM: namespace `3scale`, OperatorGroup OwnNamespace y Subscription canal **threescale-2.15**.

```bash
oc apply -k kustomize/overlays/lab-operator
```

RWX (EFS) **antes** del APIManager. Editar `fileSystemId` en `kustomize/overlays/lab-efs/kustomization.yaml`:

```bash
oc apply -k kustomize/overlays/lab-efs
```

APIManager con bases embebidas (después de CSV Succeeded y StorageClass `efs-sc`). Editar `wildcardDomain` en `kustomize/overlays/lab-apimanager/kustomization.yaml`:

```bash
oc apply -k kustomize/overlays/lab-apimanager
```

En la ventana, Redis en restore y después persistencia, todavía en 2.15:

```bash
oc apply -k kustomize/overlays/lab
# tras BGREWRITEAOF y aof_rewrite_in_progress:0, antes de devolver tráfico:
oc apply -k kustomize/overlays/lab-persist
oc -n 3scale-db rollout restart deployment/backend-redis-external deployment/system-redis-external
oc apply -k kustomize/overlays/apimanager-external
```

`apimanager-external` deja el canal en 2.15 y marca `externalComponents`. Verificar el restore en 2.15 antes del canal. No borrar los PVC embebidos.

Subir el canal a 2.16 solo después de esa verificación y del dump fresco:

```bash
oc apply -k kustomize/overlays/operator-216
```
