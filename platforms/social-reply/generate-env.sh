#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 --shared-env FILE --output FILE [--operator-email EMAIL] [--force]" >&2
}

shared_env=""
output=""
operator_email=cip@opengrowthgroup.co
force=0
while (($#)); do
  case "$1" in
    --shared-env) [[ $# -ge 2 ]] || { usage; exit 2; }; shared_env=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || { usage; exit 2; }; output=$2; shift 2 ;;
    --operator-email) [[ $# -ge 2 ]] || { usage; exit 2; }; operator_email=$2; shift 2 ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$shared_env" && -n "$output" ]] || { usage; exit 2; }
[[ -f "$shared_env" ]] || { echo "Shared env not found: $shared_env" >&2; exit 1; }
grep -qx 'PLATFORM_SLUG=social-reply' "$shared_env" || { echo "Expected the social-reply shared fragment" >&2; exit 1; }
[[ "$operator_email" == *@* ]] || { echo "--operator-email must be an email address" >&2; exit 1; }
if [[ -e "$output" && $force -ne 1 ]]; then
  echo "Refusing to overwrite $output; pass --force" >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }

random_hex() { openssl rand -hex 32; }
random_base64() { openssl rand -base64 32 | tr -d '\n'; }

mkdir -p "$(dirname "$output")"
tmp=$(mktemp "$(dirname "$output")/.social-reply.env.XXXXXX")
{
  cat "$shared_env"
  cat <<EOF
APP_URL=https://api.socialreply.com
APP_FRONTEND_URL=https://app.socialreply.com
NEXT_PUBLIC_BASE_URL=https://app.socialreply.com
NEXT_PUBLIC_API_BASE_URL=https://api.socialreply.com
NEXT_PUBLIC_REVERB_HOST=ws.socialreply.com
NEXT_PUBLIC_REVERB_PORT=443
NEXT_PUBLIC_REVERB_SCHEME=https
SOCIAL_REPLY_SOURCE_REF=09c0b41b363ee27071c0ad1e1a5e6d4b11d6cc2e
POSTGRES_IMAGE=pgvector/pgvector@sha256:3e8b3adfd27b5707128f60956f62a793c3c9326ea8cfaf0eab7adccb5d700b21
GIT_AUTH_TOKEN=
APP_KEY=base64:$(random_base64)
OPS_ADMIN_EMAILS=$operator_email
DB_DATABASE=socialreply
DB_USERNAME=socialreply
DB_PASSWORD=$(random_hex)
DB_ADMIN_PASSWORD=$(random_hex)
REVERB_APP_ID=$(random_hex)
REVERB_APP_KEY=$(random_hex)
REVERB_APP_SECRET=$(random_hex)
BILLING_ENABLED=false
BILLING_CATALOG_PUBLISH_ENABLED=false
STRIPE_WEBHOOK_TOLERANCE=300
STRIPE_API_VERSION=2025-08-27.basil
AI_DEFAULT_PROVIDER=openai
AI_DEFAULT_MODEL=gpt-5.4
AI_EMBEDDING_MODEL=text-embedding-3-small
OPENROUTER_URL=https://openrouter.ai/api/v1
YOUTUBE_BOOTSTRAP_HOURS=24
YOUTUBE_POLL_INTERVAL_SECONDS=300
YOUTUBE_POLL_OVERLAP_SECONDS=120
YOUTUBE_POLL_MAX_PAGES=5
YOUTUBE_POLL_MAX_COMMENTS=250
YOUTUBE_POLL_MAX_RUNTIME_SECONDS=20
YOUTUBE_SWEEP_BATCH_SIZE=25
YOUTUBE_VIDEO_MAX_PAGES=4
YOUTUBE_VIDEO_MAX_ITEMS=100
YOUTUBE_FAILURE_BACKOFF_SECONDS=60
YOUTUBE_QUOTA_BUDGET_UNITS=9000
YOUTUBE_REPLY_RESERVE_UNITS=1000
MAIL_FROM_ADDRESS=hello@socialreply.com
EOF
} > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
echo "Generated $output (secrets not displayed)."
