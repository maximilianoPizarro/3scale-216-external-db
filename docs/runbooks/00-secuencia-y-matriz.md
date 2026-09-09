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

No combinar el salto de 3scale y el de OCP en la misma ventana.

## Laboratorio vs destino

El overlay `lab` usa StorageClass de ejemplo `gp3-csi`. El overlay `prod` usa la StorageClass por defecto del cluster. El procedimiento 3scale es el mismo.

Despliegue de las BDD nuevas:

```bash
# Fase 1 GitOps: operador 2.15
oc apply -k gitops/
oc apply -k gitops/rhacm/                 # si el destino es un managed cluster

# Fase 2 GitOps: BDD (secret system-database en 3scale-db antes)
oc apply -k gitops/external-db
oc apply -k gitops/rhacm/external-db

# sin Argo CD
oc apply -k kustomize/overlays/lab-operator
oc apply -k kustomize/overlays/lab-efs
oc apply -k kustomize/overlays/lab-apimanager
oc apply -k kustomize/overlays/lab
```

RHACM: [gitops/rhacm/README.md](../../gitops/rhacm/README.md).

## Matriz resumida (2.16)

Consultar siempre el artículo oficial; valores de referencia:

- OpenShift: 4.14, 4.16, 4.17, 4.18, 4.19 (4.20+ en micros posteriores de 2.16)
- PostgreSQL: 14, 15 (preflight del upgrade pide ≥ 15.0 para system)
- Redis: 7.2 (dos instancias)
- Zync DB: puede permanecer interna

Oracle: revisar notas de 2.16.1 antes de planear el salto si el system DB es Oracle.
