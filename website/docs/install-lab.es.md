# Instalar 3scale 2.15 (lab)

Instalar el **operador 3scale 2.15** y un APIManager con PostgreSQL y Redis **embebidos** antes de externalizar. El overlay de BDD **no** instala el operador 3scale.

Completar primero [Requisitos previos](prerequisites.es.md).

## 1. Instalar el operador 3scale (OLM)

```bash
oc apply -k kustomize/overlays/lab-operator
oc -n 3scale get csv,subscription,pods
```

Esperar CSV `Succeeded` y el pod `threescale-operator-controller-manager-v2`.

Catálogo: `redhat-operators` / `openshift-marketplace`. En desconectado, cambiar `spec.source` de la Subscription.

## 2. Proveer volumen RWX para `system-storage`

3scale exige **ReadWriteMany** para el PVC `system-storage`. En AWS, `gp3-csi` es RWO. El PVC queda Pending (`Volume capabilities not supported`).

En laboratorio AWS: crear un filesystem EFS en la VPC del cluster (mount targets + TCP 2049 desde el SG de nodos). Luego aplicar el overlay EFS CSI:

```bash
# fileSystemId en kustomize/overlays/lab-efs/kustomization.yaml
oc apply -k kustomize/overlays/lab-efs
oc -n openshift-cluster-csi-drivers get csv,pods | grep efs
oc get sc efs-sc
```

Detalle: `kustomize/overlays/lab-efs/README.md`. En otra nube, sustituir `efs-sc` por una StorageClass RWX equivalente.

## 3. Desplegar APIManager 2.15 (PostgreSQL embebido)

Poner el dominio de apps en `kustomize/overlays/lab-apimanager/kustomization.yaml` (`REPLACE_WILDCARD_DOMAIN`, por ejemplo `apps.cluster.example.com`). El overlay ya apunta `fileStorage` a `efs-sc`.

```bash
oc apply -k kustomize/overlays/lab-apimanager
oc -n 3scale get apimanager,pods,pvc
```

Si `system-storage` nació Pending contra `gp3-csi` (APIManager aplicado antes de la SC RWX):

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
```

Cuando el APIManager esté healthy, seguir con [Externalizar PostgreSQL](externalize-postgresql.es.md) y [Externalizar Redis](externalize-redis.es.md).

## 4. Cambiar el canal del operador a 2.16 (solo después de externalizar)

```bash
oc apply -k kustomize/overlays/operator-216
```

GitOps fase 1 (operador 3scale + APIManager, no BDD):

```bash
oc apply -k gitops/
# hub ACM:
oc apply -k gitops/rhacm/
```

Poner `REPLACE_REPO_URL` en los ApplicationSet (`gitops/*.yaml`, `gitops/rhacm/*.yaml`) y el wildcard en el overlay `lab-apimanager` antes del sync.
