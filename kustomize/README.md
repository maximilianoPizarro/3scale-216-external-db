# Kustomize: bases de datos in-cluster para 3scale 2.16

La instalación soportada es el Pattern CR en `examples/pattern-cr/`. Estos bases son el layout anterior. No aplicarlos con `oc apply -k` en un cluster que ya gestiona el Pattern.

En 3scale 2.16, PostgreSQL (system) y Redis (system y backend) ya no son gestionados por el operador. Estos manifiestos despliegan esas instancias **dentro del cluster**, fuera del reconcile del `APIManager`.

Imágenes de referencia (anclar digest en cada entorno):

- `registry.redhat.io/rhel9/postgresql-15` (PostgreSQL ≥ 15.0)
- `registry.redhat.io/rhel9/redis-7` (Redis ≥ 7.2)

## Operador 3scale (laboratorio)

```bash
oc apply -k kustomize/overlays/lab-operator      # canal threescale-2.15
oc apply -k kustomize/overlays/lab-efs           # RWX (EFS); fileSystemId en el overlay
oc apply -k kustomize/overlays/lab-apimanager    # wildcardDomain + efs-sc, bases embebidas
```

En la ventana, con 3scale todavía en las bases embebidas:

```bash
oc apply -k kustomize/overlays/lab              # Redis save "" / appendonly no, para cargar dump.rdb
```

Después de `BGREWRITEAOF` y `aof_rewrite_in_progress:0`, y antes de devolver tráfico:

```bash
oc apply -k kustomize/overlays/lab-persist      # appendonly yes; el canal sigue en 2.15
oc -n 3scale-db rollout restart deployment/backend-redis-external deployment/system-redis-external
oc apply -k kustomize/overlays/apimanager-external
```

`apimanager-external` pone `externalComponents` y saca el PostgreSQL embebido del spec. No cambia la Subscription. Verificar 2.15 contra el restore (Admin Portal, Developer Portal, cuenta, APIcast, gráfico de analíticas histórico) y tomar el dump fresco. Recién ahí:

```bash
oc apply -k kustomize/overlays/operator-216     # solo el canal threescale-2.16
```

No borrar los Deployment ni los PVC embebidos al cerrar el restore. Siguen siendo el rollback hasta que `system-app-pre` termina bien. El procedimiento de dump, restore y verificación está en `docs/runbooks/`.

## Overlays

| Overlay | Uso |
|---------|-----|
| `overlays/lab` | Laboratorio AWS de ejemplo (`gp3-csi`), Redis en modo restore |
| `overlays/lab-persist` | Mismo lab, Redis con `save` y AOF, todavía en 2.15 |
| `overlays/apimanager-external` | APIManager con `externalComponents`, canal 2.15 |
| `overlays/prod` | Destino genérico; usa la StorageClass por defecto del cluster, Redis en restore |
| `overlays/prod-persist` | Destino genérico con persistencia Redis |
| `overlays/operator-216` | Solo el canal `threescale-2.16`, después de la verificación en 2.15 |

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

Antes del primer `oc apply` de `lab` o `prod`, copiar `storage` de los PVC y los `resources` de PostgreSQL y Redis desde los Deployments 2.15 que están corriendo. Los manifiestos traen `1Gi` y `2Gi` / `512Mi` como ejemplo de laboratorio. El tamaño del PVC queda fijado en ese primer apply. La guía oficial documenta un límite de 32Gi en Redis; no copiarlo si el despliegue actual usa menos. En el Pattern, los mismos números van en `threescale.storage.databaseSize` y `threescale.resources`.

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

El procedimiento de dump, restore, verificación en 2.15 y cambio de canal está en `docs/runbooks/`.
