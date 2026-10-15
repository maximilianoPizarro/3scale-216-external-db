# Secuencia de migración 2.15 → 2.16

## Orden

1. Cluster de prueba sin 3scale: instalar operador 2.15 y APIManager ([05-install-operator-lab.md](05-install-operator-lab.md)).
2. Confirmar matriz: OpenShift soportado por 2.15 **y** 2.16; último CSV del canal `threescale-2.15`.
3. Instantánea / backup de PVC y secrets (`system-database`, `system-redis`, `backend-redis`).
4. Ventana de mantenimiento: escalar a 0 el operador 3scale y los componentes de 3scale **excepto** las BDD que se están volcando.
5. Externalizar PostgreSQL 10 → 15 in-cluster ([01-externalize-postgresql.md](01-externalize-postgresql.md); Git Bash: [01-bis-externalize-postgresql-windows.md](01-bis-externalize-postgresql-windows.md)).
6. Externalizar Redis 6 → 7 in-cluster ([02-externalize-redis.md](02-externalize-redis.md); Git Bash: [02-bis-externalize-redis-windows.md](02-bis-externalize-redis-windows.md)).
7. Marcar `spec.externalComponents` en el APIManager.
8. Restaurar réplicas, validar Admin Portal, Developer Portal y APIcast.
9. Upgrade del operador al canal `threescale-2.16` ([03-upgrade-215-to-216.md](03-upgrade-215-to-216.md)).
10. Upgrade de OpenShift **después**, si aplica, según [Supported Configurations](https://access.redhat.com/articles/2798521).
11. Día 2 en `3scale-db`: Redis persistente, backups, digest ([06-day-2.md](06-day-2.md)).

Si un paso falla antes de borrar recursos embebidos: [07-rollback.md](07-rollback.md) (inglés: [en/07-rollback.md](en/07-rollback.md)). Sitio: `website/docs/rollback.md`.

No combinar el salto de 3scale y el de OCP en la misma ventana.

## Values del Pattern

| Archivo | Cuándo |
|---------|--------|
| `values-215.yaml` | Instalación. Canal `threescale-2.15`, bases embebidas, `systemStorageClass: efs-sc`. |
| `values-cutover.yaml` | Ventana. Bases externas, Redis `configMode: restore`, `externalComponents` en false. |
| `values-216-external.yaml` | Tras el restore y los portales. Canal `threescale-2.16`, `externalComponents`, auth de Redis, `configMode: persist`. |

Hace falta una StorageClass ReadWriteMany llamada `efs-sc`. Sin eso, no aplicar `hub-215.yaml`.

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
