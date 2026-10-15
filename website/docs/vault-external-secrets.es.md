# Vault y External Secrets

Esta página es el camino Kustomize. No instala el Validated Patterns Operator. No aplicar estos overlays en un cluster que ya corre ese Pattern: usan los namespaces `vault`, `external-secrets`, `3scale` y `3scale-db`, y el mismo `ClusterSecretStore` `vault-backend`.

Vault es el chart de HashiCorp `hashicorp-vault` `0.1.10`. External Secrets es la Subscription del operador `openshift-external-secrets-operator`, canal `stable-v1`. Las contraseñas quedan en `~/values-secret-3scale-216-external-db.yaml`, fuera de git.

## 1. Instalar el operador External Secrets

```bash
oc apply -k kustomize/overlays/lab-vault-operator
oc get csv -n external-secrets-operator
```

Esperar el CSV en `Succeeded`.

## 2. Instalar Vault

Editar `REPLACE_APPS_DOMAIN` en `kustomize/overlays/lab-vault/vault-values.yaml`. Es el dominio de aplicaciones, por ejemplo `apps.cluster.example.com`.

```bash
helm repo add validated-patterns https://charts.validatedpatterns.io
helm upgrade --install vault validated-patterns/hashicorp-vault \
  --version 0.1.10 \
  -n vault --create-namespace \
  -f kustomize/overlays/lab-vault/vault-values.yaml
oc get pods -n vault
```

Esperar `vault-0` en `1/1`. Inicializar y desellar. Guardar las unseal keys y el root token fuera de git. No copiarlos a tickets ni a logs.

```bash
oc exec -n vault vault-0 -c vault -- sh -c 'VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 vault operator init'
oc exec -n vault vault-0 -c vault -- sh -c 'VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 vault operator unseal'
```

Ejecutar `vault operator unseal` una vez por cada key hasta que Vault quede desellado.

## 3. Store y el Secret de la base

Editar `REPLACE_APPS_DOMAIN` en `kustomize/overlays/lab-vault/clustersecretstore.yaml`. Tiene que coincidir con `vault-values.yaml`. La ruta de Vault es `https://vault-vault.<dominio de aplicaciones>`.

```bash
oc apply -k kustomize/overlays/lab-vault
oc create secret generic vault-token -n external-secrets --from-literal=token="$VAULT_TOKEN"
```

Copiar `values-secret.yaml.template` a `~/values-secret-3scale-216-external-db.yaml`. En una migración, usar el usuario y la contraseña que ya están en el Secret `system-database` del namespace `3scale`. Sumar las contraseñas de Redis desde `system-redis` y `backend-redis` de ese namespace.

```bash
export VAULT_TOKEN
scripts/load-vault-kv.sh
oc get externalsecret -n 3scale-db system-database
oc get clustersecretstore vault-backend
```

`system-database` en `3scale-db` tiene que estar `SecretSynced` antes de que arranque PostgreSQL 15. Ese ExternalSecret es dueño del Secret. No crearlo con `oc create secret`.

## 4. Secrets de conexión

Aplicar el Secret de conexión de PostgreSQL al marcar `externalComponents.system.database`:

```bash
oc apply -k kustomize/overlays/lab-vault-components
```

`mergePolicy: Merge` escribe `URL`, `DB_USER` y `DB_PASSWORD` y deja el resto de las claves del Secret que ya existía.

Aplicar los Secrets de Redis solo cuando Redis es externo. Aplicarlos antes apunta `system-redis` y `backend-redis` a Redis 7 sin el RDB cargado.

```bash
oc apply -k kustomize/overlays/lab-vault-redis
```

Paths de KV:

| Path en Vault | Claves | Secret de Kubernetes |
|---------------|--------|----------------------|
| `secret/hub/3scale-postgresql` | `username`, `password` | `system-database` en `3scale-db` y en `3scale` |
| `secret/hub/3scale-system-redis` | `password` | `system-redis` en `3scale`, `system-redis-auth` en `3scale-db` |
| `secret/hub/3scale-backend-redis` | `password` | `backend-redis` en `3scale`, `backend-redis-auth` en `3scale-db` |

La URL de PostgreSQL no lleva puerto. Redis de system usa la base `/1`. En backend, storage usa `/0` y las colas usan `/1`. Esas URLs de Redis no llevan contraseña: los pods Redis de Kustomize no definen `requirepass`. La contraseña queda en Vault y se copia a `system-redis-auth` y `backend-redis-auth`.
