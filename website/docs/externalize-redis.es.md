# Externalizar Redis

Esta página es el mismo procedimiento que `docs/runbooks/02-externalize-redis.md`. En Git Bash, exportar `MSYS_NO_PATHCONV=1`. `docs/runbooks/02-bis-externalize-redis-windows.md` solo agrega esa regla.

Usar las mismas variables que [Externalizar PostgreSQL](externalize-postgresql.es.md). Definir `REDIS_NAMESPACE=3scale-db`.

`values-cutover.yaml` es el único archivo que pone `threescale.redis.allowRestore: true`. El chart rechaza `configMode: restore` sin esa bandera. El modo restore escribe `save ""` y `appendonly no`. Un restart no reconstruye los datos si `dump.rdb` no se cargó. Los otros values no pueden caer en restore por omisión.

Redis no tiene contraseña mientras carga el RDB. La auth y `persist` entran con `/values-215-external.yaml`, antes de devolver tráfico. El canal `threescale-2.16` es el archivo siguiente. La NetworkPolicy del cutover ya limita el puerto 6379 a los namespaces `3scale` y `3scale-db`.

No hacer `oc patch` de los Secrets de Redis ni del APIManager. ExternalSecret escribe las URL cuando `externalComponents` pasa a true.

## 1. Escalar a 0 y dejar el Redis embebido arriba

Este paso empieza después de que la externalización de PostgreSQL volvió a escalar el Redis embebido. Escalar el operador y el resto de componentes a 0. Dejar `backend-redis` y `system-redis` en el conteo capturado.

```bash
oc scale deployment threescale-operator-controller-manager-v2 -n "$OPERATOR_NAMESPACE" --replicas=0
oc scale deployment/{system-memcache,zync-database,apicast-production,apicast-staging,backend-cron,backend-listener,backend-worker,system-app,system-sidekiq,system-searchd,zync,zync-que} --replicas=0
```

Confirmar el nombre del Deployment del operador con `oc get deploy -n 3scale -o name`. En los CSV 0.12 y 0.13 es `threescale-operator-controller-manager-v2`.

## 2. SAVE y después copiar `dump.rdb`

Anotar `DBSIZE` y `LASTSAVE`, correr `SAVE` y confirmar que `LASTSAVE` avanzó. No esperar a que el proceso escriba el archivo.

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

## 3. Cargar el RDB

`/values-cutover.yaml` ya está aplicado desde el ciclo de PostgreSQL. Esperar `backend-redis-external` y `system-redis-external` en `1/1`.

```bash
export REDIS_NAMESPACE=3scale-db
oc cp ./backend-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=backend-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc cp ./system-redis-dump.rdb "$(oc get pods -n "$REDIS_NAMESPACE" -l deployment=system-redis-external -o jsonpath='{.items[0].metadata.name}')":/var/lib/redis/data/dump.rdb -n "$REDIS_NAMESPACE"
oc exec -n "$REDIS_NAMESPACE" deploy/backend-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc exec -n "$REDIS_NAMESPACE" deploy/system-redis-external -- sha256sum /var/lib/redis/data/dump.rdb
oc rollout restart deployment/backend-redis-external -n "$REDIS_NAMESPACE"
oc rollout restart deployment/system-redis-external -n "$REDIS_NAMESPACE"
```

Cuando los pods estén Ready, comparar `DBSIZE` con los números del paso 2. Después `BGREWRITEAOF` en cada pod y esperar a que `INFO persistence` muestre `aof_rewrite_in_progress:0`. Volver a leer los nombres de pod después del restart. Hasta aquí Redis sigue en modo restore (`save ""`, `appendonly no`).

## 4. Persistencia y Secrets antes de devolver tráfico

Pasar `extraValueFiles` a `/values-215-external.yaml`. Ese archivo pone `configMode: persist`, auth de Redis y `externalComponents`, y deja el canal en `threescale-2.15`. ExternalSecret reescribe las URL. No parchear Secrets ni el APIManager a mano.

El cambio de auth recrea el Deployment. Confirmar `appendonly yes` y el mismo `DBSIZE` en el pod nuevo:

```bash
oc -n 3scale-db get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
```

## 5. Verificación en 2.15 y dump fresco

Restaurar las réplicas desde `$HOME/3scale-replicas-before-cutover.json`, salvo `system-postgresql`, `backend-redis` y `system-redis` embebidos, que quedan en 0. Conservar esos PVC. El operador no sube `system-app` ni `system-sidekiq` desde 0; escalar esos dos desde el JSON. `zync-database` vuelve a 1.

En el canal `threescale-2.15`, contra las bases restauradas:

- El login del Admin Portal responde bien.
- El Developer Portal responde.
- Crear una cuenta y volver a leerla.
- Una llamada por APIcast devuelve el estado esperado para un producto configurado.
- El gráfico de analíticas muestra el tráfico histórico (confirma el RDB de `backend-redis`; una llamada nueva solo demuestra escritura).
- Conteos de cuentas, servicios y aplicaciones frente a la foto previa.
- Las colas de Sidekiq no quedan atascadas (el pod `system-sidekiq` Ready y el trabajo del portal termina).

Inmediatamente antes de `/values-216-external.yaml`, tomar un `pg_dump` nuevo y un par nuevo de `dump.rdb`. Repetir checksum y `DBSIZE`. Borrar todos los dumps cuando el upgrade esté aceptado.

## 6. Canal 2.16

`/values-216-external.yaml` solo cambia el canal a `threescale-2.16`. Las bases ya las lee 2.15. Ver [Actualizar operador a 2.16](upgrade-216.es.md).

Confirmar que el ConfigMap ya no tiene `save ""` y que `appendonly` es `yes`. Un restart en modo restore no reconstruye claves que nunca se cargaron.
