# Pin image digests

PostgreSQL 15 and Redis 7 are pinned by SHA-256 digest in `values-global.yaml`. The chart renders `image: registry.redhat.io/...@sha256:...`. A tag without a digest, including an omitted tag, is `:latest` and moves on the next pull.

Digests below are the `linux/amd64` manifests resolved from `registry.redhat.io` on 2026-10-15:

| Image | Digest |
|-------|--------|
| `registry.redhat.io/rhel9/postgresql-15` | `sha256:242c66cfab1873ecbde84ba8c8bf7488b1c40a820f41820d76efa58634519826` |
| `registry.redhat.io/rhel9/redis-7` | `sha256:81535d5fd51bc5e83108db6f86a15b6b22412922d4a590235d1fba56751b967a` |

Stay inside the 2.16 matrix: PostgreSQL 15 (system preflight ≥ 15.0) and Redis 7.2. Product matrix: [Supported Configurations](https://access.redhat.com/articles/2798521).

## Bump a digest

Resolve the new `linux/amd64` digest with a registry login. Do not commit the pull secret.

```bash
oc image info registry.redhat.io/rhel9/postgresql-15:latest --filter-by-os linux/amd64
oc image info registry.redhat.io/rhel9/redis-7:latest --filter-by-os linux/amd64
```

Put the `Digest:` line into `threescale.images` in `values-global.yaml`. Commit, push, and wait for the `external-db` Application to sync.

```bash
oc get deploy -n 3scale-db -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
oc -n 3scale-db rollout status deployment/system-postgresql-external
oc -n 3scale-db rollout status deployment/backend-redis-external
oc -n 3scale-db rollout status deployment/system-redis-external
```

Each database is one replica, `Recreate`, ReadWriteOnce. The rollout is a maintenance window.

## Next

- [Day 2 operations](day-2.md)
- [Credential rotation](credential-rotation.md)
