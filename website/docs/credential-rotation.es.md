# Rotación de credenciales

Vault lo instala el chart `hashicorp-vault`. External Secrets copia los campos del KV a los Secrets de Kubernetes que leen PostgreSQL, Redis y 3scale. Las passwords no van en git. Los valores iniciales salen de `values-secret.yaml` con `./pattern.sh make load-secrets`.

| Path en Vault | Secret de Kubernetes |
|---------------|----------------------|
| `secret/data/hub/3scale-postgresql` (`username`, `password`) | `system-database` en `3scale-db` (`DB_USER`, `DB_PASSWORD`) y en `3scale` (`URL`) |
| `secret/data/hub/3scale-system-redis` (`password`) | `system-redis` en `3scale` y `system-redis-auth` en `3scale-db` |
| `secret/data/hub/3scale-backend-redis` (`password`) | `backend-redis` en `3scale` y `backend-redis-auth` en `3scale-db` |

## Entrar y ver los secretos

El host de la Route de Vault es `vault-vault.<dominio-apps>`. El token root está en el Secret `vaultkeys` del namespace `imperative`, campo `vault_data_json`. No pegar la salida del comando en git ni en este sitio.

```bash
export VAULT_ADDR="https://$(oc get route -n vault vault -o jsonpath='{.spec.host}')"
export VAULT_TOKEN="$(oc get secret vaultkeys -n imperative -o go-template='{{index .data "vault_data_json"}}' | base64 -d | python -c 'import json,sys; print(json.load(sys.stdin)["root_token"])')"
vault login "$VAULT_TOKEN"
vault kv get secret/hub/3scale-postgresql
vault kv get secret/hub/3scale-system-redis
vault kv get secret/hub/3scale-backend-redis
oc get secret system-database -n 3scale-db -o jsonpath='{.data.DB_USER}{"\n"}' | base64 -d; echo
oc get secret system-database -n 3scale -o jsonpath='{.data.URL}{"\n"}' | base64 -d; echo
oc get secret system-redis -n 3scale -o jsonpath='{.data.URL}{"\n"}' | base64 -d; echo
oc get secret backend-redis -n 3scale -o jsonpath='{.data.REDIS_STORAGE_URL}{"\n"}{.data.REDIS_QUEUES_URL}{"\n"}' | base64 -d; echo
```

Si `./pattern.sh make install` escribió `pattern-vault.init` en el directorio del repo, `awk '/^root_token:/ {print $2}' pattern-vault.init` es el mismo token. Ese archivo está en `.gitignore`.

## Rotar PostgreSQL

Una réplica y `Recreate`: es un corte corto. Cambiar la password dentro de la base antes de reiniciar el pod. Si el pod reinicia primero, el probe usa la password nueva y el data directory sigue con la vieja.

1. `ALTER USER system PASSWORD '…'` en el pod que está corriendo, con la password actual.
2. `vault kv put secret/hub/3scale-postgresql username=system password='…'`
3. Forzar el sync del ExternalSecret y esperar a que `system-database` en `3scale-db` y el `URL` en `3scale` muestren la password nueva.

```bash
oc annotate externalsecret system-database -n 3scale-db force-sync=$(date +%s) --overwrite
oc annotate externalsecret system-database -n 3scale force-sync=$(date +%s) --overwrite
```

4. `oc rollout restart` de `system-postgresql-external` en `3scale-db`, y de `system-app` y `system-sidekiq` en `3scale`.

## Rotar Redis

1. `vault kv put` de la password nueva en `secret/hub/3scale-system-redis` o `secret/hub/3scale-backend-redis`.
2. Force-sync del ExternalSecret de auth en `3scale-db` y del de URLs en `3scale`.
3. `oc rollout restart` de `system-redis-external` o `backend-redis-external`.
4. Reiniciar los consumidores: `backend-listener`, `backend-worker`, `backend-cron`, `system-app`, `system-sidekiq`.

La primera vez que se enciende auth en un Redis que estaba abierto, se parte de URLs sin password y se siguen los mismos pasos.

## Siguiente

- [Anclar digest de imágenes](image-digests.es.md)
- [Operación día 2](day-2.es.md)
