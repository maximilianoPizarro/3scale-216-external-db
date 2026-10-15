# Externalizar PostgreSQL — Windows (Git Bash)

El procedimiento es [01-externalize-postgresql.md](01-externalize-postgresql.md). Esta página no repite otro procedimiento.

Git Bash reescribe rutas que empiezan por `/`. Sin la variable de abajo, `pg_dump -f /tmp/...` y `oc cp` apuntan al directorio temporal de Windows.

```bash
export MSYS_NO_PATHCONV=1
```

Si el destino local es `C:/...` y `oc` dice que hace falta un archivo local, copiar desde el directorio de destino con `MSYS2_ARG_CONV_EXCL='*'`.

Los dumps quedan con `chmod 600` y se borran al terminar. No commitearlos.
