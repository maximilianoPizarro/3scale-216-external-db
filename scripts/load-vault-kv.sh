#!/usr/bin/env bash
# Load ~/values-secret-3scale-216-external-db.yaml into Vault KV v2.
# Vault must already be unsealed. Export VAULT_TOKEN in the shell; do not pass it as an argument.
# The script does not print passwords or the token.
set -euo pipefail

FILE="${SECRET_FILE:-$HOME/values-secret-3scale-216-external-db.yaml}"
NS="${VAULT_NAMESPACE:-vault}"
POD="${VAULT_POD:-vault-0}"

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  echo "Set VAULT_TOKEN to the Vault root token." >&2
  exit 1
fi
if [[ ! -f "$FILE" ]]; then
  echo "Secret file not found: $FILE" >&2
  exit 1
fi

python - "$FILE" "$NS" "$POD" "$VAULT_TOKEN" <<'PY'
import subprocess, sys

path, ns, pod, token = sys.argv[1:]
secrets = {}
cur = None
field = None
for raw in open(path, encoding="utf-8"):
    line = raw.rstrip("\n")
    if line.startswith("  - name: "):
        cur = line.split(":", 1)[1].strip()
        secrets[cur] = {}
        field = None
    elif line.startswith("      - name: "):
        field = line.split(":", 1)[1].strip()
    elif line.startswith("        value: ") and cur and field:
        secrets[cur][field] = line.split(":", 1)[1].strip().strip('"').strip("'")
        field = None

needed = {
    "3scale-postgresql": ("username", "password"),
    "3scale-system-redis": ("password",),
    "3scale-backend-redis": ("password",),
}
for name, fields in needed.items():
    got = secrets.get(name) or {}
    for field_name in fields:
        if not got.get(field_name) or got[field_name].startswith("REPLACE_"):
            print(f"Missing {name}.{field_name} in the secret file.", file=sys.stderr)
            sys.exit(2)

def sh_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"

pg = secrets["3scale-postgresql"]
lines = [
    "set -eu",
    "export VAULT_ADDR=https://127.0.0.1:8200",
    "export VAULT_SKIP_VERIFY=1",
    "export VAULT_TOKEN=" + sh_quote(token),
    "if ! vault secrets list -format=json | grep -q '\"secret/\"'; then vault secrets enable -path=secret kv-v2; fi",
    "vault kv put secret/hub/3scale-postgresql username=%s password=%s >/dev/null" % (sh_quote(pg["username"]), sh_quote(pg["password"])),
    "vault kv put secret/hub/3scale-system-redis password=%s >/dev/null" % sh_quote(secrets["3scale-system-redis"]["password"]),
    "vault kv put secret/hub/3scale-backend-redis password=%s >/dev/null" % sh_quote(secrets["3scale-backend-redis"]["password"]),
    "echo vault-kv-written",
]
proc = subprocess.run(
    ["oc", "exec", "-i", "-n", ns, pod, "-c", "vault", "--", "sh", "-s"],
    input=("\n".join(lines) + "\n").encode(),
    capture_output=True,
)
out = proc.stdout.decode("utf-8", "replace")
if proc.returncode != 0 or "vault-kv-written" not in out:
    err = proc.stderr.decode("utf-8", "replace")
    for group in secrets.values():
        for value in group.values():
            if value:
                err = err.replace(value, "[redacted]")
    err = err.replace(token, "[redacted]")
    print(err[-800:] or "vault kv put failed", file=sys.stderr)
    sys.exit(proc.returncode or 1)
print("vault-kv-written")
PY
