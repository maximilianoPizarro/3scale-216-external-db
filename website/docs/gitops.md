# GitOps and RHACM

OpenShift GitOps applies this repository through the Validated Patterns Operator. The custom resource is the [Pattern](pattern-cr.md). You do not apply ApplicationSets by hand.

| Wave | Application |
|------|-------------|
| 2 | `vault`, `openshift-external-secrets` |
| 4 | `external-secrets-3scale` |
| 5 | `external-db` |
| 7 | `threescale-apimanager` |

The 3scale Subscription is rendered from `clusterGroup.subscriptions`. Watch sync with `oc get applications -n vp-gitops`. A child Application in `ComparisonError` that dials a stale repo-server clears with `argocd.argoproj.io/refresh=hard` once the current repo-server is Ready. See [Install with a Pattern CR](pattern-cr.md).

`targetRevision` in `examples/pattern-cr/` is `main`.

## Value file order on a 2.15 migration

1. `/values-215.yaml` — embedded databases.
2. `/values-cutover.yaml` — external databases, Redis `configMode: restore`, `externalComponents` still false.
3. `/values-215-external.yaml` — channel `threescale-2.15`, `externalComponents`, Redis auth, `configMode: persist`.
4. `/values-216-external.yaml` — channel `threescale-2.16` only.

Leaving the Pattern on `values-cutover.yaml` after the window means a Redis restart drops data (`save ""`, `appendonly no`). Switch to `/values-215-external.yaml` before returning traffic.

## GitOps pitfalls

!!! danger "Three cutover mistakes"
    | Risk | What to do |
    |------|------------|
    | Pattern stays on `values-cutover.yaml` | Switch `extraValueFiles` to `/values-215-external.yaml` before returning traffic, then to `/values-216-external.yaml` after the 2.15 verification. |
    | `systemStorageClass` changes from the ReadWriteMany class to `gp3-csi` | Keep `efs-sc` (or your RWX class) in `values-215-external.yaml` and `values-216-external.yaml`. |
    | Two GitOps controllers on the same cluster | Use the Patterns Operator. Do not also apply a second Argo CD Application for these charts. |

Steady state: [Day 2 operations](day-2.md). Credentials: [Credential rotation](credential-rotation.md).
