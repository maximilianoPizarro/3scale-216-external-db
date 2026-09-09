# Operación: logs, persistencia e imágenes

Tras `externalComponents`, el operador 3scale no gestiona estas BDD.

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

Fijar digest en el overlay o en `kustomize` `images:`. Tras un CVE de RHSCL, actualizar digest y hacer rollout; el operador 3scale no lo hará.

```bash
oc get deploy -n 3scale-db -o yaml | grep "image:"
```

## Red y seguridad

NetworkPolicy que permita 5432 y 6379 **solo** desde el namespace de 3scale. Pull secret de `registry.redhat.io` en `3scale-db`.
