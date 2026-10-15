# Credential rotation

The `hashicorp-vault` chart installs Vault. External Secrets copies KV fields into Kubernetes Secrets. Passwords are not stored in git.

| Vault path | Secret |
|------------|--------|
| `secret/data/hub/3scale-postgresql` | `system-database` in `3scale-db` and in `3scale` |
| `secret/data/hub/3scale-system-redis` | `system-redis` in `3scale` and `system-redis-auth` in `3scale-db` |
| `secret/data/hub/3scale-backend-redis` | `backend-redis` in `3scale` and `backend-redis-auth` in `3scale-db` |

## Log in

`make install` writes `pattern-vault.init` (gitignored). Do not paste the output into git.

```bash
export VAULT_ADDR="https://$(oc get route -n vault vault -o jsonpath='{.spec.host}')"
export VAULT_TOKEN="$(awk '/^root_token:/ {print $2}' pattern-vault.init)"
vault login "$VAULT_TOKEN"
vault kv get secret/hub/3scale-postgresql
vault kv get secret/hub/3scale-system-redis
vault kv get secret/hub/3scale-backend-redis
```

If `pattern-vault.init` is absent, `oc get secret -n vault` lists the Secret the chart created. Use that root token.

## PostgreSQL

Change the password inside the database before the pod restarts.

1. `ALTER USER system PASSWORD '…'` in the running pod.
2. `vault kv put secret/hub/3scale-postgresql username=system password='…'`
3. `oc annotate externalsecret system-database -n 3scale-db force-sync=$(date +%s) --overwrite` and the same in `3scale`.
4. `oc rollout restart` of `system-postgresql-external`, `system-app`, and `system-sidekiq`.

## Redis

1. `vault kv put` on `secret/hub/3scale-system-redis` or `secret/hub/3scale-backend-redis`.
2. Force-sync the auth ExternalSecret and the URL ExternalSecret.
3. `oc rollout restart` of that Redis and of `backend-listener`, `backend-worker`, `backend-cron`, `system-app`, `system-sidekiq`.

Site copy: `website/docs/credential-rotation.md`.
