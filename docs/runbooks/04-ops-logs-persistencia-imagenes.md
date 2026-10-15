# Operación: logs, persistencia e imágenes

Tras `externalComponents`, el operador 3scale no gestiona estas BDD. Checklist de día 2 (Redis persistente, backups, digest): [06-day-2.md](06-day-2.md).

## Logs

Los contenedores escriben a stdout/stderr (`loglevel notice` en Redis). Recogerlos con el logging del cluster, por ejemplo ClusterLogForwarder filtrando:

- `app=system-postgresql-external`
- `app=backend-redis-external`
- `app=system-redis-external`

No hay volumen extra de log en estos manifiestos.

## Persistencia

| Componente | Mount | PVC |
|------------|-------|-----|
| PostgreSQL | `/var/lib/pgsql/data` | `postgresql-data-external` |
| Redis backend | `/var/lib/redis/data` | `backend-redis-storage-external` |
| Redis system | `/var/lib/redis/data` | `system-redis-storage-external` |

Ajustar `storage` y StorageClass al tamaño real de 2.15. Programar VolumeSnapshot y `pg_dump` / `dump.rdb` periódicos.

Redis: modo restore solo durante el cutover. En régimen, ConfigMap persist (`save` + `appendonly yes`).

## Imágenes

Los bases anclan el digest en el campo `image` del Deployment. Tras un CVE de `rhel9/postgresql-15` o `rhel9/redis-7`, actualizar ese digest y hacer rollout de los tres Deployments. El operador 3scale no lo hará.

```bash
oc get deploy -n 3scale-db -o yaml | grep "image:"
```

## Red y seguridad

NetworkPolicy que permita 5432 y 6379 **solo** desde el namespace de 3scale. Pull secret de `registry.redhat.io` en `3scale-db`.
