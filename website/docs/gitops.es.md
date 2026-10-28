# GitOps y RHACM

OpenShift GitOps aplica este repositorio a través del Validated Patterns Operator. El recurso es el [Pattern](pattern-cr.es.md). No se aplican ApplicationSets a mano.

| Wave | Aplicación |
|------|------------|
| 2 | `vault`, `openshift-external-secrets` |
| 4 | `external-secrets-3scale` |
| 5 | `external-db` |
| 7 | `threescale-apimanager` |

La Subscription de 3scale sale de `clusterGroup.subscriptions`. El sync se mira con `oc get applications -n vp-gitops`. Una Application hija en `ComparisonError` que marca un repo-server viejo se limpia con `argocd.argoproj.io/refresh=hard` cuando el repo-server actual está Ready. Ver [Instalar con un Pattern CR](pattern-cr.es.md).

`targetRevision` en `examples/pattern-cr/` es `main`.

## Orden de values en una migración 2.15

1. `/values-215.yaml` — bases embebidas.
2. `/values-cutover.yaml` — bases externas, Redis `configMode: restore`, `externalComponents` sigue en false.
3. `/values-215-external.yaml` — canal `threescale-2.15`, `externalComponents`, auth de Redis, `configMode: persist`.
4. `/values-216-external.yaml` — solo canal `threescale-2.16`.

Dejar el Pattern en `values-cutover.yaml` después de la ventana hace que un reinicio de Redis pierda datos (`save ""`, `appendonly no`). Pasar a `/values-215-external.yaml` antes de devolver tráfico.

## Errores de GitOps

!!! danger "Tres errores del corte"
    | Riesgo | Qué hacer |
    |--------|-----------|
    | El Pattern se queda en `values-cutover.yaml` | Pasar `extraValueFiles` a `/values-215-external.yaml` antes de devolver tráfico, y a `/values-216-external.yaml` después de la verificación de 2.15. |
    | `systemStorageClass` pasa de la clase ReadWriteMany a `gp3-csi` | Mantener `efs-sc` (o la clase RWX) en `values-215-external.yaml` y `values-216-external.yaml`. |
    | Dos controladores de GitOps en el mismo cluster | Usar el Patterns Operator. No aplicar además otro Application de Argo CD para estos charts. |

Régimen: [Operación día 2](day-2.es.md). Credenciales: [Rotación de credenciales](credential-rotation.es.md).
