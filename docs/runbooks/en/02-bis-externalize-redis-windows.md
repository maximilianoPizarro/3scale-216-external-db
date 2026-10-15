# Externalize Redis — Windows (Git Bash)

The procedure is [02-externalize-redis.md](02-externalize-redis.md). This page does not describe a second procedure.

```bash
export MSYS_NO_PATHCONV=1
```

Without that, Git Bash rewrites `/var/lib/redis/data/dump.rdb` and `oc cp` does not copy the RDB from the pod. If the destination is `C:/...`, use `MSYS2_ARG_CONV_EXCL='*'` from the destination directory.

Compare `sha256sum` and `DBSIZE` the same way as the main procedure. Delete the `.rdb` files when finished.
