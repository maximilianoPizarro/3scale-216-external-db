# Windows / Git Bash

Usar **Git Bash (MINGW64)**, no PowerShell, para dump y restore. Los runbooks de PostgreSQL y Redis en este sitio incluyen una pestaña **Windows / Git Bash** en cada comando que difiere de Linux.

!!! warning "Git Bash reescribe rutas Unix"
    Git Bash convierte argumentos que empiezan por `/` en rutas Windows bajo `AppData/Local/Temp`. `pg_dump` escribe en la laptop, no en el pod. `oc cp pod:/var/lib/...` lee un path local y el RDB queda vacío.

## Qué hay que exportar

Exportar esto en **cada** shell antes de `oc exec`, `oc cp`, `pg_dump` o `pg_restore`:

```bash
export MSYS_NO_PATHCONV=1
```

`MSYS_NO_PATHCONV=1` desactiva esa conversión. Preferir `bash -c '...'` para que la ruta Unix viva **dentro del pod**.

## Reglas

| Hacer | No hacer |
|-------|----------|
| `oc exec ... -- bash -c 'pg_dump ... -f /tmp/db_dump.backup'` | `oc exec ... -- pg_dump ... -f /tmp/db_dump.backup` sin `bash -c` |
| `oc cp "${POD}:/tmp/db_dump.backup" ./db_dump.backup` | `oc cp ... :/tmp` solo con directorio de destino |
| `oc exec ... -- bash -c 'cat /var/lib/redis/data/dump.rdb' > ./dump.rdb` | `oc cp "$POD":/var/lib/redis/data/dump.rdb ./dump.rdb` |
| `base64 -d` o `base64 --decode` | Pegar el string base64 de `oc get secret -o yaml` en un password |

`tar: Removing leading '/' from member names` en `oc cp` es esperado. El archivo local debe empezar por `PGDMP` (PostgreSQL) o `REDIS` (Redis) y pesar más que 0.

## Dónde ejecutar los procedimientos

1. [Externalizar PostgreSQL](externalize-postgresql.es.md) — abrir la pestaña **Windows / Git Bash**
2. [Externalizar Redis](externalize-redis.es.md) — abrir la pestaña **Windows / Git Bash**

Las mismas variantes, pensadas para clonar el repo, están en:

- `docs/runbooks/01-bis-externalize-postgresql-windows.md`
- `docs/runbooks/02-bis-externalize-redis-windows.md`

## Decodificar secrets en Git Bash

```bash
oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_USER}' | base64 -d; echo
oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d; echo
```

Si `base64 -d` falla, usar `base64 --decode`.
