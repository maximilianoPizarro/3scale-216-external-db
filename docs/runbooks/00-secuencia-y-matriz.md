# Secuencia de migración 2.15 → 2.16

## Orden

1. Cluster de prueba: instalar operador 2.15 y APIManager ([05-install-operator-lab.md](05-install-operator-lab.md)).
2. Confirmar matriz: OpenShift soportado por 2.15 y 2.16; último CSV del canal `threescale-2.15`. La guía de upgrade de 2.16 lista hoy 4.12, 4.14, 4.16, 4.17, 4.18, 4.19 y 4.20. 4.13 y 4.15 no están. Si la Subscription está en aprobación manual, aprobar cada InstallPlan: el siguiente aparece cuando el anterior se instaló.
3. Backup de PVC y secrets. Un VolumeSnapshot de una base viva es crash-consistent. El CSI de EFS no implementa VolumeSnapshot.
4. Antes del primer scale-down: capturar réplicas (`oc get deploy -n 3scale -o json > "$HOME/3scale-replicas-before-cutover.json"`) y anotar desde el portal o la API la cantidad de cuentas, servicios y aplicaciones. Copiar tamaño de PVC y requests/limits de los Deployments embebidos que están corriendo; no los del ejemplo de la guía (1Gi / límite 32Gi en Redis).
5. Ciclo PostgreSQL: scale down, dump, restore, `ANALYZE`, `ALTER SCHEMA public OWNER TO system`, scale up del Redis embebido para el ciclo siguiente. Dejar el PostgreSQL embebido en 0 y conservar Deployment, Service y PVC ([01-externalize-postgresql.md](01-externalize-postgresql.md)).
6. Ciclo Redis: otro scale down, `SAVE`, `DBSIZE`, RDB, carga en Redis 7, `BGREWRITEAOF` y esperar `aof_rewrite_in_progress:0`. Conservar los PVC embebidos ([02-externalize-redis.md](02-externalize-redis.md)).
7. Pasar a `/values-215-external.yaml` (canal 2.15, `externalComponents`, auth, `persist`) antes de devolver tráfico. Confirmar `appendonly yes` y el mismo `DBSIZE` en el pod nuevo.
8. Verificación en 2.15 contra las bases restauradas: Admin Portal, Developer Portal, una cuenta nueva, una llamada por APIcast, gráfico de analíticas con tráfico histórico, y conteos frente a la foto previa. El gráfico confirma el RDB de `backend-redis`. Una llamada nueva solo demuestra escritura.
9. Dump fresco de PostgreSQL y de ambos Redis.
10. Canal `threescale-2.16` vía `/values-216-external.yaml` ([03-upgrade-215-to-216.md](03-upgrade-215-to-216.md)). Ese archivo solo cambia el canal. `SELECT version();` antes del cambio. Si hay un operador de APIcast aparte, su canal 2.16 es otra ventana (capítulo 2 de la guía).
11. Upgrade de OpenShift después, si aplica.
12. Día 2 ([06-day-2.md](06-day-2.md)).

En Git Bash, [01-bis](01-bis-externalize-postgresql-windows.md) y [02-bis](02-bis-externalize-redis-windows.md) solo agregan `MSYS_NO_PATHCONV=1`.

Hasta `system-app-pre` en 2.16, el rollback es escalar los embebidos. No borrar sus PVC al cierre de los ciclos de PostgreSQL y Redis. Después de ese Job, restore del dump fresco. No hay downgrade de OLM. El dump de laboratorio fue de 719027 bytes (base chica).

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `efs-sc`. |
| `values-cutover.yaml` | Los dos ciclos. `allowRestore: true`, sin auth de Redis, `externalComponents` en false. |
| `values-215-external.yaml` | Tras RDB y `BGREWRITEAOF`. Canal 2.15, `externalComponents`, auth, `persist`. 3scale lee las bases nuevas. |
| `values-216-external.yaml` | Tras el dump fresco y la verificación de 2.15. Solo canal `threescale-2.16`. |

EFS es el camino ReadWriteMany (`efs-sc`). Sin EFS, Local Storage Operator puede crear esa misma clase; ver [05-install-operator-lab.md](05-install-operator-lab.md). No conviven las dos.

No combinar el salto de 3scale y el de OCP en la misma ventana. Tampoco el de APIcast operator-based, si aplica.

## Values del Pattern

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Los dos ciclos. `allowRestore: true`. |
| `values-215-external.yaml` | Tras restore Redis. 2.15 sobre las bases externas. |
| `values-216-external.yaml` | Tras la verificación de 2.15. Solo canal 2.16. |

EFS es el camino ReadWriteMany (`efs-sc`). Sin EFS, aplicar `examples/local-storage/localvolume.yaml` antes de `hub-215.yaml`. No aplicar los dos a la vez.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

## Matriz resumida (2.16)

Consultar siempre el artículo oficial; valores de referencia:

- OpenShift: 4.12, 4.14, 4.16, 4.17, 4.18, 4.19, 4.20 (4.13 y 4.15 no están)
- PostgreSQL: 14, 15 (preflight del upgrade pide ≥ 15.0 para system)
- Redis: 7.2 (dos instancias)
- Zync DB: puede permanecer interna

Oracle: revisar notas de 2.16.1 antes de planear el salto si el system DB es Oracle.
