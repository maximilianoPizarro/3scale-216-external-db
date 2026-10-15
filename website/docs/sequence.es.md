# Secuencia de migración

El valor por defecto es Linux/bash. Esta página se alinea con `docs/runbooks/00-secuencia-y-matriz.md` del repositorio.

Completar [Requisitos previos](prerequisites.es.md) antes del paso 1.

## Orden de operaciones

![Secuencia de migración](images/migration-sequence.png)
*Diagrama en inglés — fases: operador 2.15 → dump → `3scale-db` → restore → GRANT → secrets → operador 2.16 → día 2.*

![Estados del namespace 3scale-db](images/namespace-3scale-db-states.png)
*Diagrama en inglés — vacío → restore PG → restore Redis (`save ""`) → persist (`appendonly yes`) → día 2.*

1. **Instalar 3scale 2.15** en un cluster de prueba — operador 3scale + APIManager con bases embebidas ([Instalar 3scale 2.15 (lab)](install-lab.es.md)).
2. **Confirmar la matriz**: versión de OpenShift soportada por 2.15 **y** 2.16; último CSV en el canal `threescale-2.15`.
3. **Instantánea / backup** de PVC y secrets (`system-database`, `system-redis`, `backend-redis`).
4. **Abrir una ventana de mantenimiento**: escalar a 0 el operador 3scale y los componentes **excepto** la base que se está volcando.
5. **Externalizar PostgreSQL** 10 → 15 in-cluster ([Externalizar PostgreSQL](externalize-postgresql.es.md)).
6. **Externalizar Redis** 6 → 7 in-cluster ([Externalizar Redis](externalize-redis.es.md)).
7. Marcar `spec.externalComponents` en el APIManager (los runbooks de PostgreSQL y Redis lo hacen).
8. **Restaurar réplicas**. Validar Admin Portal, Developer Portal y APIcast.
9. **Actualizar el operador 3scale** al canal `threescale-2.16` ([Actualizar operador a 2.16](upgrade-216.es.md)).
10. **Actualizar OpenShift** después, si aplica, según [Supported Configurations](https://access.redhat.com/articles/2798521).
11. **Operar el día 2** en `3scale-db`: `threescale.redis.configMode: persist`, backups, digest anclado ([Operación día 2](day-2.es.md), [Rotación de credenciales](credential-rotation.es.md)).

Si un paso falla antes de borrar recursos embebidos, ver [Rollback](rollback.es.md).

!!! warning "No combinar upgrades"
    No ejecutar el upgrade de 3scale y el de OpenShift en la misma ventana de mantenimiento.

## Archivos de values

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Ventana. Las bases externas existen. 3scale sigue con las embebidas. Redis `configMode: restore`, sin auth. |
| `values-216-external.yaml` | Tras el restore y los portales. Canal `threescale-2.16`, `externalComponents`, auth de Redis, `configMode: persist`. |

`values-216-singlenode.yaml` es otro escenario. Instala 2.16 directo en un nodo y no es una migración 2.15.

## Despliegue

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
./pattern.sh make load-secrets
```

En la ventana, `extraValueFiles` pasa a `/values-cutover.yaml`. Tras validar, pasa a `/values-216-external.yaml`. Ver [Instalar con un Pattern CR](pattern-cr.es.md).
