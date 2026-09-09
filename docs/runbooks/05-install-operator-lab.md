# Instalar el operador 3scale en un cluster de prueba

El overlay de BDD **no** instala el operador. En laboratorio hace falta 3scale **2.15** con PostgreSQL embebido; después se externaliza y se sube el canal a 2.16.

## 1. Operador (OLM)

```bash
oc apply -k kustomize/overlays/lab-operator
oc -n 3scale get csv,subscription,pods
```

Esperar CSV `Succeeded` y el pod `threescale-operator-controller-manager-v2`.

Catalogo: `redhat-operators` / `openshift-marketplace`. En desconectado, cambiar `spec.source` de la Subscription.

## 2. Volumen RWX para `system-storage`

3scale pide **ReadWriteMany** para el PVC `system-storage`. En AWS, `gp3-csi` es RWO y el PVC queda Pending (`Volume capabilities not supported`).

En laboratorio AWS: filesystem EFS en la VPC del cluster (mount targets + TCP 2049 desde el SG de nodos) y el overlay EFS CSI:

```bash
# fileSystemId en kustomize/overlays/lab-efs/kustomization.yaml
oc apply -k kustomize/overlays/lab-efs
oc -n openshift-cluster-csi-drivers get csv,pods | grep efs
oc get sc efs-sc
```

Detalle: [kustomize/overlays/lab-efs/README.md](../../kustomize/overlays/lab-efs/README.md). En otra nube, sustituir `efs-sc` por una StorageClass RWX equivalente.

## 3. APIManager 2.15 (PostgreSQL embebido)

En `kustomize/overlays/lab-apimanager/kustomization.yaml` poner el dominio de apps (`REPLACE_WILDCARD_DOMAIN`, por ejemplo `apps.cluster.example.com`). El overlay ya apunta `fileStorage` a `efs-sc`.

```bash
oc apply -k kustomize/overlays/lab-apimanager
oc -n 3scale get apimanager,pods,pvc
```

Si `system-storage` nació Pending contra `gp3-csi` (APIManager aplicado antes de la SC RWX):

```bash
oc -n 3scale patch apimanager apimanager --type merge \
  -p '{"spec":{"system":{"fileStorage":{"persistentVolumeClaim":{"storageClassName":"efs-sc"}}}}}'
oc -n 3scale delete pvc system-storage
# Si el operador no recrea el PVC en ~1 min, crearlo a mano con el mismo nombre,
# accessModes: [ReadWriteMany] y storageClassName: efs-sc
```

Cuando el APIManager esté healthy, seguir [01-externalize-postgresql.md](01-externalize-postgresql.md) (Windows/Git Bash: [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md)) y [02-externalize-redis.md](02-externalize-redis.md) (Windows/Git Bash: [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md)).

## 4. Canal 2.16 (solo después de externalizar)

```bash
oc apply -k kustomize/overlays/operator-216
```

GitOps fase 1 (operador + APIManager, no BDD):

```bash
oc apply -k gitops/
# hub ACM:
oc apply -k gitops/rhacm/
```

Poner `REPLACE_REPO_URL` en los ApplicationSet (`gitops/*.yaml` y `gitops/rhacm/*.yaml`) y el wildcard en el overlay `lab-apimanager` antes del sync.
