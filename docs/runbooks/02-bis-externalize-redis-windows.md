# Externalizar Redis — Windows (Git Bash)

El procedimiento es [02-externalize-redis.md](02-externalize-redis.md). Esta página no repite otro procedimiento.

```bash
export MSYS_NO_PATHCONV=1
```

Sin eso, Git Bash reescribe `/var/lib/redis/data/dump.rdb` y el `oc cp` no copia el RDB del pod. Si el destino es `C:/...`, usar `MSYS2_ARG_CONV_EXCL='*'` desde el directorio de destino.

Comparar `sha256sum` y `DBSIZE` igual que en el procedimiento principal. Borrar los `.rdb` al terminar.
