# Kustomize: bases de datos in-cluster para 3scale 2.16

En 3scale 2.16, PostgreSQL (system) y Redis (system y backend) ya no son gestionados por el operador. Estos manifiestos despliegan esas instancias **dentro del cluster**, fuera del reconcile del `APIManager`.

Imágenes de referencia (anclar digest en cada entorno):

- `registry.redhat.io/rhel9/postgresql-15` (PostgreSQL ≥ 15.0)
- `registry.redhat.io/rhel9/redis-7` (Redis ≥ 7.2)

## Operador 3scale (laboratorio)

```bash
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs          # RWX (EFS); fileSystemId en el overlay
oc apply -k kustomize/overlays/lab-apimanager   # wildcardDomain + efs-sc
oc apply -k kustomize/overlays/operator-216     # solo después de externalizar
```

## Overlays

| Overlay | Uso |
|---------|-----|
| `overlays/lab` | Laboratorio AWS de ejemplo (`gp3-csi`), Redis en modo restore |
| `overlays/lab-persist` | Mismo lab, Redis con `save` y AOF |
| `overlays/prod` | Destino genérico; usa la StorageClass por defecto del cluster |
| `overlays/prod-persist` | Destino genérico con persistencia Redis |

```bash
kustomize build kustomize/overlays/lab
oc apply -k kustomize/overlays/lab
```

Para fijar digest:

```yaml
images:
  - name: registry.redhat.io/rhel9/postgresql-15
    digest: sha256:<digest>
  - name: registry.redhat.io/rhel9/redis-7
    digest: sha256:<digest>
```

Ajustar `storage` de los PVC y los `resources` de Redis copiando los valores reales de la instalación 2.15. La guía oficial documenta un límite de 32Gi en Redis; no copiarlo si el despliegue actual usa menos.

## Secret PostgreSQL

En el namespace de las BDD (`3scale-db`):

```bash
DB_USER=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_USER}' | base64 -d)
DB_PASSWORD=$(oc get secret system-database -n "$THREESCALE_NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
oc create secret generic system-database \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  -n 3scale-db
```

El procedimiento de dump, restore y `externalComponents` está en `docs/runbooks/`.
