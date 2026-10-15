# Rotación de credenciales

Vault lo instala el chart `hashicorp-vault`. External Secrets copia el KV a los Secrets de Kubernetes. Las passwords no van en git.

| Path en Vault | Secret |
|---------------|--------|
| `secret/data/hub/3scale-postgresql` | `system-database` en `3scale-db` y en `3scale` |
| `secret/data/hub/3scale-system-redis` | `system-redis` en `3scale` y `system-redis-auth` en `3scale-db` |
| `secret/data/hub/3scale-backend-redis` | `backend-redis` en `3scale` y `backend-redis-auth` en `3scale-db` |

## Entrar

`make install` escribe `pattern-vault.init` (gitignored). No pegar la salida en git.

```bash
export VAULT_ADDR="https://$(oc get route -n vault vault -o jsonpath='{.spec.host}')"
export VAULT_TOKEN="$(awk '/^root_token:/ {print $2}' pattern-vault.init)"
vault login "$VAULT_TOKEN"
vault kv get secret/hub/3scale-postgresql
vault kv get secret/hub/3scale-system-redis
vault kv get secret/hub/3scale-backend-redis
```

Si no existe `pattern-vault.init`, `oc get secret -n vault` lista el Secret del chart. Usar ese token root.

## PostgreSQL

Cambiar la password en la base antes de reiniciar el pod.

1. `ALTER USER system PASSWORD '…'` en el pod que está corriendo.
2. `vault kv put secret/hub/3scale-postgresql username=system password='…'`
3. `oc annotate externalsecret system-database -n 3scale-db force-sync=$(date +%s) --overwrite` y lo mismo en `3scale`.
4. `oc rollout restart` de `system-postgresql-external`, `system-app` y `system-sidekiq`.

## Redis

1. `vault kv put` en `secret/hub/3scale-system-redis` o `secret/hub/3scale-backend-redis`.
2. Force-sync del ExternalSecret de auth y del de URLs.
3. `oc rollout restart` del Redis y de `backend-listener`, `backend-worker`, `backend-cron`, `system-app`, `system-sidekiq`.

Copia del sitio: `website/docs/credential-rotation.md`.
