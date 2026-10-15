# Anclar digest de imágenes

PostgreSQL 15 y Redis 7 van anclados por digest SHA-256 en `values-global.yaml`. El chart renderiza `image: registry.redhat.io/...@sha256:...`. Un tag sin digest, incluido el tag omitido, es `:latest` y cambia en el próximo pull.

Los digest de abajo son los manifiestos `linux/amd64` resueltos en `registry.redhat.io` el 2026-10-15:

| Imagen | Digest |
|--------|--------|
| `registry.redhat.io/rhel9/postgresql-15` | `sha256:242c66cfab1873ecbde84ba8c8bf7488b1c40a820f41820d76efa58634519826` |
| `registry.redhat.io/rhel9/redis-7` | `sha256:81535d5fd51bc5e83108db6f86a15b6b22412922d4a590235d1fba56751b967a` |

Quedar dentro de la matriz 2.16: PostgreSQL 15 (preflight del system ≥ 15.0) y Redis 7.2. Matriz: [Supported Configurations](https://access.redhat.com/articles/2798521).

## Subir un digest

Resolver el digest `linux/amd64` nuevo con login al registry. No commitear el pull secret.

```bash
oc image info registry.redhat.io/rhel9/postgresql-15:latest --filter-by-os linux/amd64
oc image info registry.redhat.io/rhel9/redis-7:latest --filter-by-os linux/amd64
```

Copiar la línea `Digest:` a `threescale.images` en `values-global.yaml`. Commit, push, y esperar el sync de la Application `external-db`.

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc -n 3scale-db rollout status deployment/system-postgresql-external
oc -n 3scale-db rollout status deployment/backend-redis-external
oc -n 3scale-db rollout status deployment/system-redis-external
```

Cada base es una réplica, `Recreate`, ReadWriteOnce. El rollout es una ventana de mantenimiento.

## Siguiente

- [Operación día 2](day-2.es.md)
- [Rotación de credenciales](credential-rotation.es.md)
