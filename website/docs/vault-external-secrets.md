# Vault and External Secrets

This page is the Kustomize path. It does not install the Validated Patterns Operator. Do not apply these overlays on a cluster that already runs that Pattern: both use namespaces `vault`, `external-secrets`, `3scale`, and `3scale-db`, and the same `ClusterSecretStore` name `vault-backend`.

Vault is the HashiCorp chart `hashicorp-vault` `0.1.10`. External Secrets is the OpenShift operator Subscription `openshift-external-secrets-operator`, channel `stable-v1`. Passwords stay in `~/values-secret-3scale-216-external-db.yaml`, not in git.

## 1. Install the External Secrets operator

```bash
oc apply -k kustomize/overlays/lab-vault-operator
oc get csv -n external-secrets-operator
```

Wait until the CSV is `Succeeded`.

## 2. Install Vault

Edit `REPLACE_APPS_DOMAIN` in `kustomize/overlays/lab-vault/vault-values.yaml`. Use the apps domain, for example `apps.cluster.example.com`.

```bash
helm repo add validated-patterns https://charts.validatedpatterns.io
helm upgrade --install vault validated-patterns/hashicorp-vault \
  --version 0.1.10 \
  -n vault --create-namespace \
  -f kustomize/overlays/lab-vault/vault-values.yaml
oc get pods -n vault
```

Wait until `vault-0` is `1/1`. Initialize and unseal it. Keep the unseal keys and the root token outside git. Do not print them into tickets or logs.

```bash
oc exec -n vault vault-0 -c vault -- sh -c 'VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 vault operator init'
oc exec -n vault vault-0 -c vault -- sh -c 'VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 vault operator unseal'
```

Run `vault operator unseal` once per key until Vault reports unsealed.

## 3. Store and the database secret

Edit `REPLACE_APPS_DOMAIN` in `kustomize/overlays/lab-vault/clustersecretstore.yaml`. It must match `vault-values.yaml`. The Vault route is `https://vault-vault.<apps domain>`.

```bash
oc apply -k kustomize/overlays/lab-vault
oc create secret generic vault-token -n external-secrets --from-literal=token="$VAULT_TOKEN"
```

Copy `values-secret.yaml.template` to `~/values-secret-3scale-216-external-db.yaml`. For a migration, use the username and password already stored in Secret `system-database` in namespace `3scale`. Add the Redis passwords from `system-redis` and `backend-redis` in that same namespace.

```bash
export VAULT_TOKEN
scripts/load-vault-kv.sh
oc get externalsecret -n 3scale-db system-database
oc get clustersecretstore vault-backend
```

`system-database` in `3scale-db` must be `SecretSynced` before PostgreSQL 15 starts. That ExternalSecret owns the Secret. Do not create it with `oc create secret`.

## 4. Connection secrets

Apply the PostgreSQL connection secret when you set `externalComponents.system.database`:

```bash
oc apply -k kustomize/overlays/lab-vault-components
```

`mergePolicy: Merge` writes `URL`, `DB_USER`, and `DB_PASSWORD` and leaves the other keys in the existing Secret.

Apply the Redis secrets only when Redis is external. Applying them earlier points `system-redis` and `backend-redis` at Redis 7 before the RDB is loaded.

```bash
oc apply -k kustomize/overlays/lab-vault-redis
```

KV paths:

| Vault path | Keys | Kubernetes Secret |
|------------|------|-------------------|
| `secret/hub/3scale-postgresql` | `username`, `password` | `system-database` in `3scale-db` and in `3scale` |
| `secret/hub/3scale-system-redis` | `password` | `system-redis` in `3scale`, `system-redis-auth` in `3scale-db` |
| `secret/hub/3scale-backend-redis` | `password` | `backend-redis` in `3scale`, `backend-redis-auth` in `3scale-db` |

The PostgreSQL URL has no port. System Redis uses database `/1`. Backend storage uses `/0` and queues use `/1`. Those Redis URLs have no password: the Kustomize Redis pods do not set `requirepass`. The password is still stored in Vault and copied to `system-redis-auth` and `backend-redis-auth`.
