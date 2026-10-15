# Kustomize: bases de datos in-cluster para 3scale 2.16

Estos overlays no se aplican en un cluster que ya gestiona el Validated Pattern. Comparten los namespaces `vault`, `external-secrets`, `3scale` y `3scale-db`.

En 3scale 2.16, PostgreSQL (system) y Redis (system y backend) ya no son gestionados por el operador. Estos manifiestos despliegan esas instancias **dentro del cluster**, fuera del reconcile del `APIManager`.

Imágenes de referencia (anclar digest en cada entorno):

- `registry.redhat.io/rhel9/postgresql-15` (PostgreSQL ≥ 15.0)
- `registry.redhat.io/rhel9/redis-7` (Redis ≥ 7.2)

## Operador 3scale (laboratorio)

```bash
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-vault-operator
# Helm: hashicorp-vault 0.1.10. Ver website/docs/vault-external-secrets.es.md
oc apply -k kustomize/overlays/lab-efs          # RWX (EFS); fileSystemId en el overlay
oc apply -k kustomize/overlays/lab-apimanager   # wildcardDomain + efs-sc
oc apply -k kustomize/overlays/operator-216     # solo después de externalizar
```

## Overlays

| Overlay | Uso |
|---------|-----|
| `overlays/lab-vault-operator` | Subscription de External Secrets (`stable-v1`) |
| `overlays/lab-vault` | ClusterSecretStore y Secret de PostgreSQL en `3scale-db` |
| `overlays/lab-vault-components` | URL de PostgreSQL en el namespace `3scale` |
| `overlays/lab-vault-redis` | Secrets de Redis al externalizar Redis |
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

Lo escribe el ExternalSecret `system-database` en `3scale-db` desde Vault. No crearlo con `oc create secret`. Procedimiento: `website/docs/vault-external-secrets.es.md`.

El procedimiento de dump, restore y `externalComponents` está en `docs/runbooks/`.
