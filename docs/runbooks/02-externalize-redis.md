# Externalizar Redis (6 → 7) in-cluster

Procedimiento único, el mismo que `website/docs/externalize-redis.es.md`. En Git Bash: [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md) solo agrega `MSYS_NO_PATHCONV=1`.

`values-cutover.yaml` es el único archivo con `allowRestore: true`. El chart rechaza `configMode: restore` sin esa bandera. Ese modo deja `save ""` y `appendonly no`: un restart no reconstruye datos si el RDB no se cargó. Redis sigue sin auth solo durante la carga. La auth y `persist` entran con `/values-215-external.yaml`, antes de devolver tráfico. El canal `threescale-2.16` es el archivo siguiente.

## 1. Escalar a 0 y dejar Redis embebido arriba

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Confirmar el nombre del Deployment del operador. En 0.12 y 0.13 es `threescale-operator-controller-manager-v2`.

## 2. SAVE y copiar `dump.rdb`

```bash
for dep in backend-redis system-redis; do
  pod=$(oc get pods -l deployment=$dep -o jsonpath='{.items[0].metadata.name}')
  echo "$dep before $(oc exec "$pod" -- redis-cli DBSIZE) lastsave $(oc exec "$pod" -- redis-cli LASTSAVE)"
  oc exec "$pod" -- redis-cli SAVE
  echo "$dep after-save $(oc exec "$pod" -- redis-cli LASTSAVE)"
done
oc cp "$(oc get pods -l deployment=backend-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./backend-redis-dump.rdb
oc cp "$(oc get pods -l deployment=system-redis -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb ./system-redis-dump.rdb
sha256sum ./backend-redis-dump.rdb ./system-redis-dump.rdb
wc -c ./backend-redis-dump.rdb ./system-redis-dump.rdb
chmod 600 ./backend-redis-dump.rdb ./system-redis-dump.rdb
oc scale deployment/system-redis --replicas=0
oc scale deployment/backend-redis --replicas=0
```

`LASTSAVE` tiene que avanzar. No esperar a que Redis escriba solo.

## 3. Cargar el RDB

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc exec -n "$REDIS_NAMESPACE" deploy/backend-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc exec -n "$REDIS_NAMESPACE" deploy/system-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

Comparar `DBSIZE` con el paso 2. Después `BGREWRITEAOF` y esperar `aof_rewrite_in_progress:0`. Hasta aquí Redis sigue en modo restore (`save ""`, `appendonly no`).

## 4. Persistencia y Secrets antes de devolver tráfico

Pasar `extraValueFiles` a `/values-215-external.yaml`. Ese archivo pone `configMode: persist`, auth de Redis y `externalComponents`, y deja el canal en `threescale-2.15`. ExternalSecret reescribe las URL. No parchear Secrets ni el APIManager a mano. Argo pisa ese cambio.

El cambio de auth recrea el Deployment. Confirmar `appendonly yes` y el mismo `DBSIZE` en el pod nuevo:

```bash
oc -n 3scale-db get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
oc exec -n 3scale-db deploy/backend-redis-external -- redis-cli -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE
oc exec -n 3scale-db deploy/system-redis-external -- redis-cli -a "$REDIS_PASSWORD" --no-auth-warning DBSIZE
```

## 5. Verificación en 2.15 y dump fresco

Restaurar réplicas desde `$HOME/3scale-replicas-before-cutover.json`. El operador no sube `system-app` ni `system-sidekiq` desde 0; escalar esos dos desde el JSON. Dejar PostgreSQL y Redis embebidos en 0 y conservar sus PVC. `zync-database` vuelve a 1.

En 2.15, contra las bases restauradas:

- Login del Admin Portal.
- Developer Portal.
- Alta y lectura de una cuenta.
- Una llamada por APIcast.
- Gráfico de analíticas con el tráfico histórico (confirma el RDB de `backend-redis`; una llamada nueva solo demuestra escritura).
- Conteos de cuentas, servicios y aplicaciones frente a la foto previa.
- Sidekiq sin atasco.

Inmediatamente antes de `/values-216-external.yaml`, repetir `pg_dump` y los dos `dump.rdb` con checksum y `DBSIZE`.

## 6. Canal 2.16

`/values-216-external.yaml` solo cambia el canal a `threescale-2.16`. Las bases ya las lee 2.15. Ver [03-upgrade-215-to-216.md](03-upgrade-215-to-216.md).

## Rollback

Hasta `system-app-pre` en 2.16, escalar el Redis embebido. No borrar sus PVC. La guía oficial los borra al final del capítulo; aquí no. Después de ese Job, restaurar el dump fresco.
