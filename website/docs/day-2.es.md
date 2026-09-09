# Operación día 2

Tras marcar `externalComponents`, el **operador 3scale** sigue gestionando `system-app`, APIcast y Zync. Ya no gestiona PostgreSQL (system) ni Redis (system y backend). Quien opera el namespace `3scale-db` es dueño de esos Deployments, PVC, imágenes, backups y NetworkPolicy.

Copia para clonar el repo: `docs/runbooks/06-day-2.md`. Referencia corta: `docs/runbooks/04-ops-logs-persistencia-imagenes.md`.

!!! danger "Redis tiene que quedar en modo persistencia"
    El cutover usa `save ""` y `appendonly no` para que Redis cargue `dump.rdb`. En régimen el ConfigMap tiene que salir de `kustomize/bases/redis-config-persist` (`save` + `appendonly yes`).
    Si GitOps vuelve a `redis-config-restore`, un restart **borra datos**.

## Checklist en régimen

- [ ] El ConfigMap de Redis tiene líneas `save` y `appendonly yes` (no `save ""`)
- [ ] En GitOps, `redis-config.path` es `kustomize/bases/redis-config-persist` (o se aplicó `*-persist`)
- [ ] Los digest de imagen están anclados (PostgreSQL 15 y Redis 7), no el tag flotante
- [ ] Tamaño de PVC y `resources` coinciden con la carga de 2.15 (los valores de lab son ejemplos)
- [ ] `pg_dump` + VolumeSnapshot periódicos de PostgreSQL
- [ ] `SAVE` / `dump.rdb` / AOF + VolumeSnapshot periódicos de Redis
- [ ] Backup de secrets `system-database`, `system-redis` y `backend-redis` en el namespace `3scale` **y** de `system-database` en `3scale-db`
- [ ] Hubo al menos un ejercicio de restore
- [ ] ClusterLogForwarder (o equivalente) recolecta stdout de los tres pods de BDD
- [ ] NetworkPolicy permite 5432 y 6379 **solo** desde el namespace de 3scale
- [ ] Hay pull secret de `registry.redhat.io` en `3scale-db`
- [ ] El on-call sabe que un drain de nodo o un rollout de imagen de estos Deployments es un corte (`Recreate`, 1 réplica, RWO)

## Quién opera qué

| Área | Responsable tras `externalComponents` |
|------|---------------------------------------|
| PostgreSQL y ambos Redis (pod, PVC, imagen, probes) | Quien opera las BDD (manifiestos / GitOps de `3scale-db`) |
| Secrets con los que 3scale se conecta | Quien opera 3scale, en el namespace `3scale` |
| `system-app`, APIcast, Sidekiq, Searchd, Zync, `zync-database` | Operador 3scale |
| `system-storage` (RWX) | Operador 3scale / APIManager |

Borrar el `APIManager` **no** debe borrar los PVC de `3scale-db` (sin `ownerReferences`; GitOps `prune: false`). Borrar el namespace `3scale-db` **sí** borra los datos.

## Confirmar persistencia de Redis

```bash
oc -n 3scale-db get configmap redis-config-external -o yaml | grep -E 'save |appendonly'
```

Debe haber `save 900 1` (y el resto de `save`) y `appendonly yes`. **No** dejar `save ""` ni `appendonly no` después del cutover.

Aplicar la config persistente:

```bash
# lab
oc apply -k kustomize/overlays/lab-persist

# StorageClass por defecto
oc apply -k kustomize/overlays/prod-persist
```

Con GitOps, poner `redis-config.path` en `kustomize/bases/redis-config-persist` en el ApplicationSet de BDD y reiniciar:

```bash
oc -n 3scale-db rollout restart deployment/backend-redis-external deployment/system-redis-external
```

## Backups

| Componente | Qué copiar | PVC |
|------------|------------|-----|
| PostgreSQL | `pg_dump` (formato custom) + VolumeSnapshot | `postgresql-data-external` |
| Redis backend | `redis-cli SAVE`, luego `dump.rdb` / AOF + snapshot | `backend-redis-storage-external` |
| Redis system | igual | `system-redis-storage-external` |

Guardar copia de los secrets de conexión. Tras un restore como usuario `postgres`, volver a aplicar el GRANT de PostgreSQL 15 (abajo).

En Git Bash, exportar `MSYS_NO_PATHCONV=1` y seguir [Windows / Git Bash](windows.es.md) antes de cualquier path de `oc exec` que empiece por `/`.

!!! warning "No hay alta disponibilidad"
    Cada base es **una réplica**, `Recreate`, ReadWriteOnce. Red Hat no soporta Redis Cluster para 3scale. Un drain de nodo o un rollout de imagen es ventana de mantenimiento.

## Anclar y parchear digest de imagen

El operador 3scale ya no dispara ImageChange sobre estos Deployments. Anclar digest SHA-256 del [catálogo de Red Hat](https://catalog.redhat.com/). Quedar dentro de la matriz de 2.16: PostgreSQL 14/15 (preflight del system ≥ 15.0), Redis 7.2.

En el overlay (`kustomize/overlays/lab-persist` o `prod-persist`):

```yaml
images:
  - name: registry.redhat.io/rhel9/postgresql-15
    digest: sha256:<digest>
  - name: registry.redhat.io/rhel9/redis-7
    digest: sha256:<digest>
```

Inventario y rollout:

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc apply -k kustomize/overlays/lab-persist
oc -n 3scale-db rollout status deployment/system-postgresql-external
oc -n 3scale-db rollout status deployment/backend-redis-external
oc -n 3scale-db rollout status deployment/system-redis-external
```

Un CVE de RHSCL exige un rollout propio. Es un corte de esa base. El operador 3scale no lo dispara.

## Capacidad

Los PVC de lab son `1Gi`. Los límites de memoria de lab son `2Gi`. Copiar requests, limits y `storage` de los Deployments embebidos de 2.15. No copiar el límite 32Gi de Redis de la guía oficial si producción usa menos.

Vigilar llenado de PVC y memoria de Redis. Redis vive en RAM.

## Red, logs y secrets

- Permitir TCP **5432** y **6379** solo desde el namespace de 3scale.
- Recoger stdout/stderr (`loglevel notice` en Redis). Filtrar por `app=system-postgresql-external`, `app=backend-redis-external`, `app=system-redis-external`. Estos manifiestos no montan un volumen de log.
- Rotar passwords en **ambos** namespaces: `system-database` en `3scale-db` (env del pod) y `URL` / URLs de Redis en `3scale`. Luego reiniciar PostgreSQL y `system-app`.

## GRANT de PostgreSQL 15

Mantener `USAGE, CREATE` en el schema `public` para el usuario `system`. Si se restaura un dump como `postgres` y se omite esto, `system-app-pre` falla con `permission denied for schema public`:

```bash
oc exec -n 3scale-db deploy/system-postgresql-external -- \
  psql -U postgres -d system -c 'GRANT USAGE, CREATE ON SCHEMA public TO system; ALTER SCHEMA public OWNER TO system;'
```

## Riesgos de GitOps

| Riesgo | Qué hacer |
|--------|-----------|
| El ApplicationSet sigue listando `redis-config-restore` | Cambiar el path a `redis-config-persist` después del cutover. `selfHeal: true` revertirá un edit manual del ConfigMap. |
| `prune: true` | Dejar `prune: false` para que un sync no borre PVC. |
| Mezclar GitOps in-cluster y RHACM | Un solo controlador por destino. Ver [GitOps y RHACM](gitops.es.md). |

## Ventanas de upgrade

No combinar un upgrade de OpenShift con uno del operador 3scale. Un micro de 2.16 **no** parchea estas bases. Parchear PostgreSQL y Redis por separado y mantener versiones en la matriz de [Supported Configurations](https://access.redhat.com/articles/2798521).

`zync-database` puede seguir interna. No meterla en el runbook de `3scale-db`.

## Siguientes pasos

- [Documentación oficial](official-docs.es.md)
- [FAQ de operación](faq.es.md)
- [GitOps y RHACM](gitops.es.md)
- [Actualizar operador a 2.16](upgrade-216.es.md)
