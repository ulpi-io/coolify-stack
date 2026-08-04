#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 --shared-env FILE --output FILE --claude-token-file FILE --resend-key-file FILE [--admin-email EMAIL] [--force]" >&2
}

shared_env=""
output=""
claude_token_file=""
resend_key_file=""
admin_email=cip@opengrowthgroup.co
force=0
while (($#)); do
  case "$1" in
    --shared-env) [[ $# -ge 2 ]] || { usage; exit 2; }; shared_env=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || { usage; exit 2; }; output=$2; shift 2 ;;
    --claude-token-file) [[ $# -ge 2 ]] || { usage; exit 2; }; claude_token_file=$2; shift 2 ;;
    --resend-key-file) [[ $# -ge 2 ]] || { usage; exit 2; }; resend_key_file=$2; shift 2 ;;
    --admin-email) [[ $# -ge 2 ]] || { usage; exit 2; }; admin_email=$2; shift 2 ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$shared_env" && -n "$output" && -n "$claude_token_file" && -n "$resend_key_file" ]] || { usage; exit 2; }
[[ -f "$shared_env" && ! -L "$shared_env" ]] || { echo "Shared env must be a regular, non-symlink file: $shared_env" >&2; exit 1; }
grep -qx 'PLATFORM_SLUG=qm' "$shared_env" || { echo "Expected the qm shared fragment" >&2; exit 1; }
[[ "$admin_email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || { echo "--admin-email must be an email address" >&2; exit 1; }
if [[ -e "$output" && $force -ne 1 ]]; then
  echo "Refusing to overwrite $output; pass --force" >&2
  exit 1
fi
for command_name in openssl node; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "$command_name is required" >&2; exit 1; }
done

read_secret_file() {
  local path=$1 label=$2 mode value line_count
  [[ -f "$path" && ! -L "$path" ]] || { echo "$label must be a regular, non-symlink file" >&2; exit 1; }
  mode=$(stat -f '%Lp' "$path" 2>/dev/null || stat -c '%a' "$path")
  [[ "$mode" == 600 ]] || { echo "$label must have mode 0600" >&2; exit 1; }
  line_count=$(wc -l < "$path" | tr -d ' ')
  (( line_count <= 1 )) || { echo "$label must contain exactly one value" >&2; exit 1; }
  value=$(tr -d '\r\n' < "$path")
  (( ${#value} >= 32 )) || { echo "$label is too short" >&2; exit 1; }
  printf '%s' "$value"
}

random_hex() { openssl rand -hex 32; }
generate_jwk() {
  node -e 'const {generateKeyPairSync}=require("node:crypto");const {privateKey}=generateKeyPairSync("ec",{namedCurve:"P-256"});process.stdout.write(JSON.stringify(privateKey.export({format:"jwk"})));'
}

claude_token=$(read_secret_file "$claude_token_file" "--claude-token-file")
resend_key=$(read_secret_file "$resend_key_file" "--resend-key-file")

mkdir -p "$(dirname "$output")"
tmp=$(mktemp "$(dirname "$output")/.qm.env.XXXXXX")
{
  cat "$shared_env"
  cat <<EOF
APP_URL=https://agents.con.fyi
QM_SOURCE_REF=5eb3393315b45b338b860572ab516db9f6eae6da
GIT_AUTH_TOKEN=
ADMIN_GRANTS=$admin_email:org_admin
AUTH_ALLOWED_EMAILS=$admin_email,tania@opengrowthgroup.co
CLAUDE_CODE_OAUTH_TOKEN=$claude_token
CORE_SIGNING_SECRET=$(random_hex)
CAPABILITY_SECRET=$(random_hex)
PORTAL_IDENTITY_SECRET=$(random_hex)
CONNECTOR_SECRET_KEY=$(random_hex)
SKILL_SIGNING_SECRET=$(random_hex)
PORTAL_SESSION_SECRET=$(random_hex)
AUTH_CLIENT_SECRET=$(random_hex)
AUTH_TOKEN_SECRET=$(random_hex)
AUTH_SIGNING_JWK=$(generate_jwk)
AUTH_EMAIL_FROM=Agents <no-reply@agents.con.fyi>
RESEND_API_KEY=$resend_key
EOF
} > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
unset claude_token resend_key
echo "Generated $output (secrets not displayed)."
