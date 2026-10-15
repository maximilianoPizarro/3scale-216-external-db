# Rollback

Usar esta página cuando el cutover falla **antes** de que `system-app-pre` termine bien en 2.16. Hasta ese momento los Deployments embebidos quedan en 0 réplicas y sus PVC se conservan. Copia para clonar el repo: `docs/runbooks/07-rollback.md` (inglés: `docs/runbooks/en/07-rollback.md`).

Después de que `system-app-pre` termina bien, las escrituras nuevas existen solo en la base externa. Volver a escalar las bases embebidas pierde esas escrituras. El rollback es un restore del dump fresco tomado justo antes de `/values-216-external.yaml`. No hay downgrade de OLM.

![Rutas de ownership y rollback](images/ownership-and-rollback.png)

## Quién opera qué

| Namespace | Gestiona el operador | Gestiona quien opera la plataforma |
|-----------|----------------------|---------------|
| `3scale` | `system-app`, APIcast, Zync, `zync-database`, `system-storage` | Secrets de conexión, escritos por ExternalSecret desde Vault |
| `3scale-db` | Nada del operador 3scale tras `externalComponents` | PostgreSQL 15, ambos Redis 7, PVC, imágenes, backups, NetworkPolicy |

Ver [Motivación](why.es.md) para *external ≠ off-cluster* y qué deja de reconciliar el operador.

## Falla el restore de PostgreSQL

1. Volver `externalComponents.system.database` a `false` en el APIManager.
2. Reaplicar PostgreSQL embebido en el spec del APIManager si hace falta: `spec.system.database.postgresql: {}`.
3. Restaurar el secret `system-database` desde el backup (`system-database-secret.yaml`).
4. Subir el operador 3scale y `system-postgresql` embebido.
5. Validar Admin Portal y APIs contra los datos embebidos.
6. **No** borrar el PVC nuevo de PostgreSQL en `3scale-db` hasta confirmar el embebido.

## RDB de Redis vacío o falla el restore

1. Volver `externalComponents.system.redis` y `externalComponents.backend.redis` a `false`.
2. Restaurar secrets `system-redis` y `backend-redis` desde backup.
3. Subir `backend-redis` y `system-redis` embebidos en 3scale 2.15.
4. Validar portales y tráfico de API.
5. **No** borrar los PVC nuevos de Redis en `3scale-db` hasta confirmar el embebido.

Si `dump.rdb` quedó vacío en Git Bash, usar `docs/runbooks/02-bis-externalize-redis-windows.md` (`MSYS_NO_PATHCONV=1`, `oc exec` + `cat`) y repetir [Externalizar Redis](externalize-redis.es.md).

## Bucle de preflight del operador 3scale 2.16

Síntomas: el operador 2.16 se instala pero el upgrade de instancia no completa; los chequeos de versión fallan cada ~10 minutos.

1. Confirmar PostgreSQL ≥ 15.0 y Redis ≥ 7.2 en los pods externos ([Actualizar operador a 2.16](upgrade-216.es.md#ejecutar-comprobaciones-de-preflight)).
2. Aplicar el GRANT de PostgreSQL 15 si `system-app-pre` reporta `permission denied for schema public` — ver [GRANT CREATE en schema `public`](externalize-postgresql.es.md#grant-create-en-schema-public).
3. Borrar el Job `system-app-pre` y dejar que el operador lo recree.
4. **No** combinar upgrade de OpenShift y de 3scale en la misma ventana.
5. Si las versiones no se pueden corregir a tiempo, quedarse en canal `threescale-2.15` hasta cumplir preflight.

## Trampa GitOps (Redis)

Si el Pattern sigue en `values-cutover.yaml`, un restart del pod puede **borrar datos de Redis**. Pasar `extraValueFiles` a `/values-216-external.yaml` antes de dar por cerrada la migración. Ver [Errores de GitOps](gitops.es.md#errores-de-gitops) y [Operación día 2](day-2.es.md).

## Próximos pasos

- [Secuencia de migración](sequence.es.md)
- [Operación día 2](day-2.es.md)
- [FAQ de operación](faq.es.md)
