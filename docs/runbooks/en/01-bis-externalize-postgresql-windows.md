# Externalize PostgreSQL — Windows (Git Bash)

The procedure is [01-externalize-postgresql.md](01-externalize-postgresql.md). This page does not describe a second procedure.

Git Bash rewrites paths that start with `/`. Without the variable below, `pg_dump -f /tmp/...` and `oc cp` target the Windows temp directory.

```bash
export MSYS_NO_PATHCONV=1
```

If the local destination is `C:/...` and `oc` says one side must be a local file, copy from the destination directory with `MSYS2_ARG_CONV_EXCL='*'`.

Dumps stay at mode `600` and are deleted when finished. Do not commit them.
