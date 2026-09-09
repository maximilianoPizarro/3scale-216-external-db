# FAQ de operación

Preguntas habituales al pasar de 3scale 2.15 (BDD embebidas) a 2.16, manteniendo PostgreSQL y Redis **dentro del cluster** pero **fuera del ciclo de vida del operador 3scale**.

## ¿“External” implica sacar las BDD del cluster?

No. En la documentación, *external* significa que las bases **no forman parte de la instalación 3scale** y **no las reconcilia el operador**. Pueden vivir en el mismo cluster, incluso en el mismo namespace (no recomendado). Un namespace dedicado (`3scale-db` en este repositorio) es el patrón habitual.

`zync-database` puede seguir como componente interno del operador.

## ¿Quién opera logs y persistencia en disco?

Tras marcar `spec.externalComponents`, el operador 3scale **deja de reconciliar** el Deployment y el PVC:

| Área | Responsable |
|------|-------------|
| Ciclo de vida del pod | Quien opera las BDD (estos manifiestos / GitOps) |
| Persistencia | PVC + StorageClass + VolumeSnapshot / backups |
| Logs | stdout/stderr → stack de logging del cluster |
| Parches de imagen RHSCL | Quien opera las BDD |
| Conexión desde 3scale | Secrets en el namespace de 3scale |

Borrar el `APIManager` no debe borrar los PVC externos. Los recursos de este paquete no llevan `ownerReferences` del APIManager.

## ¿Qué versiones de imagen hay que fijar?

Preflight de 2.16 (cada ~10 minutos):

- PostgreSQL ≥ 15.0 (system)
- Redis ≥ 7.2 (system + backend)

Imágenes usadas en la guía oficial y en este repo:

- `registry.redhat.io/rhel9/postgresql-15`
- `registry.redhat.io/rhel9/redis-7`

Anclar **digest SHA-256**, no el tag flotante.

## Redis restore vs persistencia

Redis en modo restore (`save ""`, `appendonly no`) solo durante el cutover para cargar `dump.rdb`. Después hay que pasar a persistencia (`lab-persist` o `redis-config-persist`); si no, un restart pierde datos.

## ¿Se puede probar en OpenShift 4.19 si producción está en un minor menor?

Sí, para validar 2.16 con BDD self-managed. En el cluster a migrar, confirmar que el OCP actual entra en la matriz de **2.15 y 2.16**. Secuencia: último micro de 2.15 → externalizar PG y Redis **en 2.15** → operador 2.16 → upgrade de OCP después.

## ¿Dónde está el procedimiento completo?

Runbooks detallados en el repositorio:

1. `docs/runbooks/00-secuencia-y-matriz.md`
2. `docs/runbooks/01-externalize-postgresql.md`
3. `docs/runbooks/02-externalize-redis.md`
4. `docs/runbooks/03-upgrade-215-to-216.md`
5. `docs/runbooks/04-ops-logs-persistencia-imagenes.md`

Referencia: `docs/faq-externalizacion.md`.
