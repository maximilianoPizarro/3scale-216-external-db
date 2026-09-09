# Operador 3scale (laboratorio)

Instala OLM: namespace `3scale`, OperatorGroup OwnNamespace y Subscription canal **threescale-2.15**.

```bash
oc apply -k kustomize/overlays/lab-operator
```

RWX (EFS) **antes** del APIManager. Editar `fileSystemId` en `kustomize/overlays/lab-efs/kustomization.yaml`:

```bash
oc apply -k kustomize/overlays/lab-efs
```

APIManager (después de CSV Succeeded y StorageClass `efs-sc`). Editar `wildcardDomain` en `kustomize/overlays/lab-apimanager/kustomization.yaml`:

```bash
oc apply -k kustomize/overlays/lab-apimanager
```

Subir a 2.16 solo tras externalizar las BDD:

```bash
oc apply -k kustomize/overlays/operator-216
```
