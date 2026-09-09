# Windows / Git Bash

Use **Git Bash (MINGW64)**, not PowerShell, for dump and restore. The PostgreSQL and Redis runbooks on this site include a **Windows / Git Bash** tab for every command that differs from Linux.

!!! warning "Git Bash rewrites Unix paths"
    Git Bash converts arguments that start with `/` into Windows paths under `AppData/Local/Temp`. `pg_dump` then writes on the laptop, not in the pod. `oc cp pod:/var/lib/...` reads a local path and the RDB copy is empty.

## What you must set

Export this in **every** shell before `oc exec`, `oc cp`, `pg_dump`, or `pg_restore`:

```bash
export MSYS_NO_PATHCONV=1
```

`MSYS_NO_PATHCONV=1` disables that conversion. Prefer `bash -c '...'` so the Unix path lives **inside the pod**.

## Rules

| Do | Do not |
|----|--------|
| `oc exec ... -- bash -c 'pg_dump ... -f /tmp/db_dump.backup'` | `oc exec ... -- pg_dump ... -f /tmp/db_dump.backup` without `bash -c` |
| `oc cp "${POD}:/tmp/db_dump.backup" ./db_dump.backup` | `oc cp ... :/tmp` with a trailing directory only |
| `oc exec ... -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./dump.rdb` | `oc cp "$POD":/var/lib/redis/data/dump.rdb ./dump.rdb` |
| `base64 -d` or `base64 --decode` | Paste the base64 string from `oc get secret -o yaml` into a password prompt |

`tar: Removing leading '/' from member names` on `oc cp` is expected. The local file must still start with `PGDMP` (PostgreSQL) or `REDIS` (Redis) and have size greater than 0.

## Where to run the procedures

1. [Externalize PostgreSQL](externalize-postgresql.md) — open the **Windows / Git Bash** tab
2. [Externalize Redis](externalize-redis.md) — open the **Windows / Git Bash** tab

Clone-friendly copies of the same variants live in the repository:

- `docs/runbooks/01-bis-externalize-postgresql-windows.md`
- `docs/runbooks/02-bis-externalize-redis-windows.md`

## Decode secrets on Git Bash

```bash
oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_USER}' | base64 -d; echo
oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d; echo
```

If `base64 -d` fails, use `base64 --decode`.
