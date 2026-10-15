# Secuencia de migración

El valor por defecto es Linux/bash. Esta página coincide con `docs/runbooks/00-secuencia-y-matriz.md`. En Git Bash se sigue ese mismo procedimiento con `MSYS_NO_PATHCONV=1` (`docs/runbooks/01-bis` y `02-bis` solo agregan la regla de rutas de Windows).

Completar [Requisitos previos](prerequisites.es.md) antes del paso 1.

## Orden de operaciones

![Secuencia de migración](images/migration-sequence.png)
*Diagrama en inglés — fases: operador 2.15 → dump → `3scale-db` → restore → GRANT → secrets → operador 2.16 → día 2.*

![Estados del namespace 3scale-db](images/namespace-3scale-db-states.png)
*Diagrama en inglés — vacío → restore PG → restore Redis (`save ""`) → persist (`appendonly yes`) → día 2.*

1. **Instalar 3scale 2.15** con bases embebidas ([Instalar 3scale 2.15 (lab)](install-lab.es.md)).
2. **Confirmar la matriz**: OpenShift soportado por 2.15 y 2.16; último CSV en `threescale-2.15`.
3. **Respaldar** PVC y secrets de conexión. Un VolumeSnapshot de un PVC con la base viva es crash-consistent. El CSI de EFS no implementa VolumeSnapshot: `system-storage` se respalda con AWS Backup o una copia de archivos.
4. **Capturar réplicas** antes del primer scale-down. El archivo queda fuera del repo:

    ```bash
    oc get deploy -n 3scale -o json > "$HOME/3scale-replicas-before-cutover.json"
    ```

5. **Ciclo 1, PostgreSQL.** Escalar a 0 el operador y los componentes, salvo `system-postgresql`. Dump, restore en PostgreSQL 15, `ANALYZE`, comparar conteos, volver a escalar la aplicación. El operador no sube `system-app` ni `system-sidekiq` desde 0; usar el JSON. Dejar el Deployment embebido en 0 y **conservar** su PVC. [Externalizar PostgreSQL](externalize-postgresql.es.md).
6. **Ciclo 2, Redis.** Volver a escalar a 0, salvo el Redis embebido que se está volcando. `SAVE`, comparar `LASTSAVE` y `DBSIZE`, copiar `dump.rdb`, cargarlo en Redis 7, volver a escalar. Dejar el Redis embebido en 0 y **conservar** esos PVC. [Externalizar Redis](externalize-redis.es.md).
7. **Smoke test en 2.15** contra las bases externas: login de admin, alta y lectura de una cuenta, una llamada por APIcast, colas de Sidekiq sin atasco.
8. **Dump fresco** de PostgreSQL y de ambos Redis inmediatamente antes del cambio de canal. Es un segundo backup, además del que abrió la ventana.
9. **Cambiar el canal** poniendo `extraValueFiles` del Pattern en `/values-216-external.yaml`. Ese archivo fija `threescale-2.16`. Correr `SELECT version();` en el servidor antes del cambio. [Actualizar operador a 2.16](upgrade-216.es.md).
10. **Actualizar OpenShift después**, si hace falta. No combinarlo con el upgrade de 3scale.
11. **Día 2** en `3scale-db`: Redis `persist`, digest anclados, backups. [Operación día 2](day-2.es.md).

Hasta que `system-app-pre` corrió en 2.16, el rollback es volver a escalar las bases embebidas. Después de ese Job, las escrituras nuevas viven solo en la base externa. El rollback es un restore del dump fresco. No hay downgrade de OLM.

El dump de PostgreSQL del laboratorio fue de 719027 bytes. Esa cifra es una base chica, no una estimación de producción.

!!! warning "No combinar upgrades"
    No ejecutar el upgrade de 3scale y el de OpenShift en la misma ventana de mantenimiento.

## Archivos de values

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Los dos ciclos de dump y restore. Las bases externas existen. 3scale sigue con las embebidas hasta el archivo siguiente. Redis `configMode: restore` solo porque este archivo pone `allowRestore: true`. Sin auth de Redis. |
| `values-216-external.yaml` | Tras el dump fresco y el smoke test de 2.15. Canal `threescale-2.16`, `externalComponents`, auth de Redis, `configMode: persist`. |

GitOps es la fuente de verdad. `extraValueFiles` es el cambio. Vault y ExternalSecret escriben los Secrets. Argo pisa un `oc patch` manual de esos Secrets o del APIManager.

`values-216-singlenode.yaml` instala 2.16 directo en un nodo. No es esta migración.

## Despliegue

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
```

En la ventana, `extraValueFiles` pasa a `/values-cutover.yaml`. Tras el dump fresco y el smoke test, pasa a `/values-216-external.yaml`. Ver [Instalar con un Pattern CR](pattern-cr.es.md).
