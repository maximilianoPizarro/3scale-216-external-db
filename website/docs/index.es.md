# Migración 3scale 2.15 → 2.16

Manifiestos y runbooks reutilizables para **externalizar** PostgreSQL (system) y Redis (system y backend) **dentro de OpenShift** antes de actualizar el operador 3scale a **2.16**.

Todos los procedimientos de este sitio asumen **Linux** (bash). Para variantes en **Windows / Git Bash**, ver el [README del repositorio](https://github.com/maximilianoPizarro/3scale-migration-216#español).

## Qué incluye

| Área | Ubicación en el repo |
|------|----------------------|
| Bases y overlays Kustomize | `kustomize/` |
| Runbooks operativos (español) | `docs/runbooks/` |
| OpenShift GitOps / Argo CD | `gitops/` |
| Patrones RHACM (hub) | `gitops/rhacm/` |

## Ruta rápida

1. [Motivación](why.es.md)
2. [Documentación oficial de Red Hat](official-docs.es.md)
3. [Secuencia de migración](sequence.es.md) (Linux)
4. [Versiones probadas](tested-versions.es.md)
