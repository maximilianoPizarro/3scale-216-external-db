# Anclar digest de imágenes

PostgreSQL 15 y Redis 7 van por digest SHA-256 en `values-global.yaml`. El chart renderiza `image: registry.redhat.io/...@sha256:...`. Un tag sin digest, o un nombre sin tag, es `:latest`.

Digest `linux/amd64` resueltos en `registry.redhat.io` el 2026-10-15:

| Imagen | Digest |
|--------|--------|
| `registry.redhat.io/rhel9/postgresql-15` | `sha256:242c66cfab1873ecbde84ba8c8bf7488b1c40a820f41820d76efa58634519826` |
| `registry.redhat.io/rhel9/redis-7` | `sha256:81535d5fd51bc5e83108db6f86a15b6b22412922d4a590235d1fba56751b967a` |

## Subir un digest

No commitear el pull secret.

```bash
oc image info registry.redhat.io/rhel9/postgresql-15:latest --filter-by-os linux/amd64
oc image info registry.redhat.io/rhel9/redis-7:latest --filter-by-os linux/amd64
```

Copiar la línea `Digest:` a `threescale.images` en `values-global.yaml`. Commit, push y esperar el sync de `external-db`. Cada base es una réplica, `Recreate`, ReadWriteOnce: el rollout es ventana.

Copia del sitio: `website/docs/image-digests.md`.
