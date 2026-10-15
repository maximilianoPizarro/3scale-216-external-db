# Credential rotation

Vault is installed by the `hashicorp-vault` chart. External Secrets copies the KV fields into the Kubernetes Secrets that PostgreSQL, Redis, and 3scale read. Passwords are not stored in git. The initial values come from `values-secret.yaml` via `./pattern.sh make load-secrets`.

| Vault path | Kubernetes Secret |
|------------|-------------------|
| `secret/data/hub/3scale-postgresql` (`username`, `password`) | `system-database` in `3scale-db` (`DB_USER`, `DB_PASSWORD`) and in `3scale` (`URL`) |
| `secret/data/hub/3scale-system-redis` (`password`) | `system-redis` in `3scale` and `system-redis-auth` in `3scale-db` |
| `secret/data/hub/3scale-backend-redis` (`password`) | `backend-redis` in `3scale` and `backend-redis-auth` in `3scale-db` |

## Log in and read the secrets

The Vault route host is `vault-vault.<apps-domain>`. The root token is in Secret `vaultkeys` in namespace `imperative`, field `vault_data_json`. Do not paste the command output into git or into this site.

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

If `./pattern.sh make install` wrote `pattern-vault.init` in the repository directory, `awk '/^root_token:/ {print $2}' pattern-vault.init` is the same token. That file is gitignored.

## Rotate PostgreSQL

One replica and `Recreate`: this is a short outage. Change the password inside the database before the pod restarts. If the pod restarts first, the readiness probe uses the new password and the data directory still has the old one.

1. `ALTER USER system PASSWORD '…'` in the running pod, using the current password.
2. `vault kv put secret/hub/3scale-postgresql username=system password='…'`
3. Force the ExternalSecret sync and wait until `system-database` in `3scale-db` and the `URL` in `3scale` show the new password.

```bash
oc annotate externalsecret system-database -n 3scale-db force-sync=$(date +%s) --overwrite
oc annotate externalsecret system-database -n 3scale force-sync=$(date +%s) --overwrite
```

4. `oc rollout restart` of `system-postgresql-external` in `3scale-db`, then `system-app` and `system-sidekiq` in `3scale`.

## Rotate Redis

1. `vault kv put` the new password on `secret/hub/3scale-system-redis` or `secret/hub/3scale-backend-redis`.
2. Force-sync the auth ExternalSecret in `3scale-db` and the URL ExternalSecret in `3scale`.
3. `oc rollout restart` of `system-redis-external` or `backend-redis-external`.
4. Restart the consumers: `backend-listener`, `backend-worker`, `backend-cron`, `system-app`, `system-sidekiq`.

The first time auth is enabled on a Redis that was open, start from URLs without a password and follow the same steps.

## Next

- [Pin image digests](image-digests.md)
- [Day 2 operations](day-2.md)
