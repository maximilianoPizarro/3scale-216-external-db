#!/bin/bash
# Build GitHub Pages with two selectable versions:
#   validated-pattern  (this branch)
#   1.0.0              (tag v1.0.0, Kustomize, no Pattern CR)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/website/site"
BASE="https://maximilianopizarro.github.io/3scale-216-external-db"

if [[ -x "$ROOT/.venv/Scripts/python.exe" ]]; then
  MKDOCS=("$ROOT/.venv/Scripts/python.exe" -m mkdocs)
elif [[ -x "$ROOT/.venv/bin/python" ]]; then
  MKDOCS=("$ROOT/.venv/bin/python" -m mkdocs)
else
  MKDOCS=(mkdocs)
fi

WT="$(mktemp -d)"
cleanup() {
  git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -f "$ROOT/website/mkdocs.ci.yml"
}
trap cleanup EXIT

rm -rf "$SITE"
mkdir -p "$SITE"

git -C "$ROOT" worktree add --detach "$WT" v1.0.0

python - "$WT/website/mkdocs.yml" "$WT/website/docs/index.md" "$WT/website/docs/index.es.md" <<'PY'
import pathlib, sys
mkdocs, index_en, index_es = map(pathlib.Path, sys.argv[1:])
text = mkdocs.read_text(encoding="utf-8")
old_url = "site_url: https://maximilianopizarro.github.io/3scale-216-external-db/"
new_url = "site_url: https://maximilianopizarro.github.io/3scale-216-external-db/1.0.0/"
if old_url not in text:
    raise SystemExit("v1.0.0 site_url not found")
text = text.replace(old_url, new_url, 1)
needle = "extra:\n  generator: false"
insert = "extra:\n  version:\n    provider: mike\n    default: validated-pattern\n  generator: false"
if needle not in text:
    raise SystemExit("v1.0.0 extra block not found")
mkdocs.write_text(text.replace(needle, insert, 1), encoding="utf-8")

def banner(path, paragraph):
    body = path.read_text(encoding="utf-8")
    if "version selector" in body or "selector de versión" in body:
        return
    lines = body.splitlines()
    lines.insert(2, "")
    lines.insert(3, paragraph)
    lines.insert(4, "")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

banner(index_en, "This page is version **1.0.0**: Kustomize and GitOps, without a Pattern CR. **Validated Pattern** in the version selector is the newer guide.")
banner(index_es, "Esta página es la versión **1.0.0**: Kustomize y GitOps, sin Pattern CR. **Validated Pattern** en el selector de versión es la guía nueva.")
PY

(cd "$WT/website" && "${MKDOCS[@]}" build --strict --site-dir "$SITE/1.0.0")

python - "$ROOT/website/mkdocs.yml" "$ROOT/website/mkdocs.ci.yml" <<'PY'
import pathlib, sys
src, dst = map(pathlib.Path, sys.argv[1:])
text = src.read_text(encoding="utf-8")
old_url = "site_url: https://maximilianopizarro.github.io/3scale-216-external-db/"
new_url = "site_url: https://maximilianopizarro.github.io/3scale-216-external-db/validated-pattern/"
if old_url not in text:
    raise SystemExit("current site_url not found")
dst.write_text(text.replace(old_url, new_url, 1), encoding="utf-8")
PY

(cd "$ROOT/website" && "${MKDOCS[@]}" build --strict -f mkdocs.ci.yml --site-dir "$SITE/validated-pattern")

python - "$SITE" "$BASE" <<'PY'
import json, pathlib, sys
site = pathlib.Path(sys.argv[1])
base = sys.argv[2]
(site / "versions.json").write_text(json.dumps([
    {"version": "validated-pattern", "title": "Validated Pattern", "aliases": ["latest"]},
    {"version": "1.0.0", "title": "1.0.0", "aliases": []},
], indent=2) + "\n", encoding="utf-8")

def redirect(path, target, label):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\">"
        f"<meta http-equiv=\"refresh\" content=\"0; url={target}\">"
        f"<link rel=\"canonical\" href=\"{base}/{target}\">"
        f"<title>{label}</title></head><body>"
        f"<p><a href=\"{target}\">{label}</a></p>"
        "<p><a href=\"validated-pattern/\">Validated Pattern</a> · "
        "<a href=\"1.0.0/\">1.0.0</a></p>"
        "</body></html>\n",
        encoding="utf-8",
    )

redirect(site / "index.html", "validated-pattern/", "Validated Pattern")
redirect(site / "latest" / "index.html", "../validated-pattern/", "Validated Pattern")
PY

echo "versioned site: $SITE"
