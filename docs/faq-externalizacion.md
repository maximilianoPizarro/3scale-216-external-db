# FAQ: bases de datos self-managed en 3scale 2.16

Preguntas habituales al pasar de 3scale 2.15 (BDD embebidas) a 2.16, manteniendo PostgreSQL y Redis **dentro del cluster** pero **fuera del ciclo de vida del operador 3scale**.

Fuentes: [Externalizing databases for 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/externalizing-databases), [Upgrade 2.15 to 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/upgrade-operator), [Supported Configurations](https://access.redhat.com/articles/2798521).

## ¿“External” implica sacar las BDD del cluster?

No. En la documentación, *external* significa que las bases **no forman parte de la instalación 3scale** y **no las reconcilia el operador**. Pueden vivir en el mismo cluster, incluso en el mismo namespace (no recomendado). Un namespace dedicado (`3scale-db` en este repositorio) es el patrón habitual.

La excepción es `zync-database`: puede seguir como componente interno del operador.

## ¿Quién opera logs y persistencia en disco?

El operador 3scale **deja de reconciliar** el Deployment y el PVC al marcar `spec.externalComponents`. A partir de ahí:

| Área | Responsable |
|------|-------------|
| Ciclo de vida del pod (Deployment, probes, imagen) | Quien opera las BDD (estos manifiestos / GitOps) |
| Persistencia | PVC + StorageClass + VolumeSnapshot / backups |
| Logs | stdout/stderr del contenedor → stack de logging del cluster (ClusterLogForwarder, Loki, Elasticsearch, SIEM) |
| Rotación de logs de motor | No la hace el operador 3scale |
| Parches de imagen `rhel9/postgresql-15` y `rhel9/redis-7` | Quien opera las BDD (el operador ya no dispara ImageChange sobre esos Deployments) |
| Conexión desde 3scale | Secrets `system-database`, `system-redis`, `backend-redis` en el namespace de 3scale |

Borrar el `APIManager` no debe borrar los PVC. Los recursos de este paquete no llevan `ownerReferences` del APIManager.

## ¿Qué versiones de imagen hay que fijar?

Preflight de 2.16 (el operador 2.16 comprueba cada ~10 minutos):

- PostgreSQL ≥ 15.0 (system)
- Redis ≥ 7.2 (dos instancias: system y backend)
- Este repo fija PostgreSQL 15 porque el preflight exige ≥ 15.0. Redis 7.2. Valkey 7.2/8.0 es alternativa documentada por el producto, no por este procedimiento.

Imágenes usadas en la guía oficial y en este repo:

- `registry.redhat.io/rhel9/postgresql-15`
- `registry.redhat.io/rhel9/redis-7`

Anclar **digest SHA-256** (catálogo de Red Hat), no el tag flotante. Inventario:

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

## ¿Qué más hay que administrar?

- Ventana de mantenimiento: 3scale **abajo** durante dump/restore.
- Redis en modo restore (`save ""`, `appendonly no`) solo para copiar `dump.rdb`. Después pasar a `/values-215-external.yaml` (`configMode: persist`) antes de devolver tráfico; si no, un restart pierde datos. El canal 2.16 es `/values-216-external.yaml`.
- Copiar requests/limits reales de 2.15 (`threescale.resources` y `databaseSize`). No asumir el límite 32Gi de Redis que aparece en la guía.
- Backups: `pg_dump` + snapshots de volumen; Redis `SAVE` / `dump.rdb` / AOF + snapshots.
- Red Hat no soporta Redis Cluster ni un diseño oficial de HA/zero-downtime. Sentinel queda como referencia. Este paquete replica el modelo Deployment+PVC de 2.15.
- NetworkPolicy, pull secret de `registry.redhat.io`, SCC/PSA, StorageClass RWO.
- No mezclar upgrade de OpenShift y upgrade de 3scale en la misma ventana.

## ¿Se puede probar en OpenShift 4.19 si el cluster a migrar está en un minor menor?

Sí, para validar 2.16 con BDD self-managed. La guía de upgrade de 2.16 lista hoy 4.12, 4.14, 4.16–4.20. 4.13 y 4.15 no están. La externalización no depende del minor.

En el cluster que se va a migrar, confirmar que el OCP actual entra en la matriz de **2.15 y 2.16**. Si la Subscription está en aprobación manual, aprobar cada InstallPlan. Secuencia: último micro de 2.15 → externalizar PG 10→15 y Redis 6→7 **en 2.15** → verificar 2.15 sobre el restore → operator 2.16 → upgrade de OCP después, según matriz. Un operador de APIcast aparte es otra ventana.

El hardware del laboratorio no tiene que coincidir con producción. Ver [docs/lab/dimensionamiento-ocp419.md](lab/dimensionamiento-ocp419.md).

## ¿Dónde está el procedimiento?

1. [docs/runbooks/00-secuencia-y-matriz.md](runbooks/00-secuencia-y-matriz.md)
2. [docs/runbooks/01-externalize-postgresql.md](runbooks/01-externalize-postgresql.md) (Windows/Git Bash: [01-bis-externalize-postgresql-windows.md](runbooks/01-bis-externalize-postgresql-windows.md))
3. [docs/runbooks/02-externalize-redis.md](runbooks/02-externalize-redis.md) (Windows/Git Bash: [02-bis-externalize-redis-windows.md](runbooks/02-bis-externalize-redis-windows.md))
4. [docs/runbooks/03-upgrade-215-to-216.md](runbooks/03-upgrade-215-to-216.md)
5. [docs/runbooks/04-ops-logs-persistencia-imagenes.md](runbooks/04-ops-logs-persistencia-imagenes.md)
6. [docs/runbooks/06-day-2.md](runbooks/06-day-2.md)
7. [docs/runbooks/07-rollback.md](runbooks/07-rollback.md) (inglés: [en/07-rollback.md](runbooks/en/07-rollback.md))

Inglés completo: `docs/runbooks/en/` (`00`–`07`).
