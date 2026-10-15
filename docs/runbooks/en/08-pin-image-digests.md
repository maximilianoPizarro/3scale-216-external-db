# Pin image digests

PostgreSQL 15 and Redis 7 are pinned by SHA-256 digest in `values-global.yaml`. The chart renders `image: registry.redhat.io/...@sha256:...`. A tag without a digest, or a name with no tag, is `:latest`.

`linux/amd64` digests resolved from `registry.redhat.io` on 2026-10-15:

| Image | Digest |
|-------|--------|
| `registry.redhat.io/rhel9/postgresql-15` | `sha256:242c66cfab1873ecbde84ba8c8bf7488b1c40a820f41820d76efa58634519826` |
| `registry.redhat.io/rhel9/redis-7` | `sha256:81535d5fd51bc5e83108db6f86a15b6b22412922d4a590235d1fba56751b967a` |

## Bump a digest

Do not commit the pull secret.

```bash
oc image info registry.redhat.io/rhel9/postgresql-15:latest --filter-by-os linux/amd64
oc image info registry.redhat.io/rhel9/redis-7:latest --filter-by-os linux/amd64
```

Copy the `Digest:` line into `threescale.images` in `values-global.yaml`. Commit, push, and wait for the `external-db` Application to sync. Each database is one replica, `Recreate`, ReadWriteOnce: the rollout is a maintenance window.

Site copy: `website/docs/image-digests.md`.
