# Official documentation

Red Hat guides for this migration:

## Primary guides

| Topic | Link |
|-------|------|
| **Migrating 3scale 2.16** (overview) | [Migrating Red Hat 3scale API Management 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/index) |
| **Externalizing databases** | [Externalizing databases](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/externalizing-databases) |
| **Upgrade operator 2.15 → 2.16** | [Upgrade 2.15 to 2.16](https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.16/html/migrating_red_hat_3scale_api_management/upgrade-operator) |
| **Supported configurations** | [Supported Configurations](https://access.redhat.com/articles/2798521) |

## How this repo maps to the guide

| Official chapter | This repository |
|------------------|-----------------|
| PostgreSQL 10 upgrade — on-cluster | [Externalize PostgreSQL](externalize-postgresql.md) + `kustomize/bases/postgresql` |
| Redis 6 upgrade — on-cluster | [Externalize Redis](externalize-redis.md) + `kustomize/bases/redis-*` |
| Operator upgrade | [Upgrade operator to 2.16](upgrade-216.md) + `kustomize/overlays/operator-216` |
| Lab install before externalization | [Install 3scale 2.15 (lab)](install-lab.md) |
| Day 2 (self-managed databases) | [Day 2 operations](day-2.md) + `docs/runbooks/06-day-2.md` |

Clone-friendly operational steps (Spanish) remain in the repository under `docs/runbooks/`.
