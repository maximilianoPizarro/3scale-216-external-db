# Secuencia de migración 2.15 → 2.16

## Orden

1. Cluster de prueba: instalar operador 2.15 y APIManager ([05-install-operator-lab.md](05-install-operator-lab.md)).
2. Confirmar matriz: OpenShift soportado por 2.15 y 2.16; último CSV del canal `threescale-2.15`.
3. Backup de PVC y secrets. Un VolumeSnapshot de una base viva es crash-consistent. El CSI de EFS no implementa VolumeSnapshot.
4. Capturar réplicas fuera del repo: `oc get deploy -n 3scale -o json > "$HOME/3scale-replicas-before-cutover.json"`.
5. Ciclo PostgreSQL: scale down, dump, restore, `ANALYZE`, scale up. El operador no sube `system-app` ni `system-sidekiq` desde 0. Dejar el embebido en 0 y conservar el PVC ([01-externalize-postgresql.md](01-externalize-postgresql.md)).
6. Ciclo Redis: otro scale down, `SAVE`, `DBSIZE`, RDB, scale up. Conservar los PVC embebidos ([02-externalize-redis.md](02-externalize-redis.md)).
7. Smoke test en 2.15 contra las bases externas.
8. Dump fresco de PostgreSQL y de ambos Redis.
9. Canal `threescale-2.16` vía `/values-216-external.yaml` ([03-upgrade-215-to-216.md](03-upgrade-215-to-216.md)). `SELECT version();` antes del cambio.
10. Upgrade de OpenShift después, si aplica.
11. Día 2 ([06-day-2.md](06-day-2.md)).

En Git Bash, [01-bis](01-bis-externalize-postgresql-windows.md) y [02-bis](02-bis-externalize-redis-windows.md) solo agregan `MSYS_NO_PATHCONV=1`.

Hasta `system-app-pre` en 2.16, el rollback es escalar los embebidos. Después, restore del dump fresco. No hay downgrade de OLM. El dump de laboratorio fue de 719027 bytes (base chica).

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `efs-sc`. |
| `values-cutover.yaml` | Los dos ciclos. `allowRestore: true`, sin auth de Redis, `externalComponents` en false. |
| `values-216-external.yaml` | Tras el dump fresco y el smoke test. Canal 2.16, `externalComponents`, auth, `persist`. |

EFS es el camino ReadWriteMany (`efs-sc`). Sin EFS, Local Storage Operator puede crear esa misma clase; ver [05-install-operator-lab.md](05-install-operator-lab.md). No conviven las dos.

No combinar el salto de 3scale y el de OCP en la misma ventana.

## Values del Pattern

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Los dos ciclos. `allowRestore: true`. |
| `values-216-external.yaml` | Tras el dump fresco y el smoke test. |

EFS es el camino ReadWriteMany (`efs-sc`). Sin EFS, aplicar `examples/local-storage/localvolume.yaml` antes de `hub-215.yaml`. No aplicar los dos a la vez.

```bash
oc apply -f examples/pattern-cr/hub-215.yaml
cp values-secret.yaml.template ~/values-secret-3scale-216-external-db.yaml
./pattern.sh make load-secrets
```

## Matriz resumida (2.16)

Consultar siempre el artículo oficial; valores de referencia:

- OpenShift: 4.14, 4.16, 4.17, 4.18, 4.19 (4.20+ en micros posteriores de 2.16)
- PostgreSQL: 14, 15 (preflight del upgrade pide ≥ 15.0 para system)
- Redis: 7.2 (dos instancias)
- Zync DB: puede permanecer interna

Oracle: revisar notas de 2.16.1 antes de planear el salto si el system DB es Oracle.
