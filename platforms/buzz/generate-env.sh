#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 --shared-env FILE --output FILE --owner-pubkey HEX [--force]" >&2
}

shared_env=""
output=""
owner_pubkey=""
force=0
while (($#)); do
  case "$1" in
    --shared-env) [[ $# -ge 2 ]] || { usage; exit 2; }; shared_env=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || { usage; exit 2; }; output=$2; shift 2 ;;
    --owner-pubkey) [[ $# -ge 2 ]] || { usage; exit 2; }; owner_pubkey=$2; shift 2 ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$shared_env" && -n "$output" && -n "$owner_pubkey" ]] || { usage; exit 2; }
[[ -f "$shared_env" ]] || { echo "Shared env not found: $shared_env" >&2; exit 1; }
grep -qx 'PLATFORM_SLUG=buzz' "$shared_env" || { echo "Expected the buzz shared fragment" >&2; exit 1; }
[[ "$owner_pubkey" =~ ^[[:xdigit:]]{64}$ ]] || {
  echo "--owner-pubkey must be a 64-character hex Nostr public key" >&2
  exit 1
}
owner_pubkey=$(printf '%s' "$owner_pubkey" | tr '[:upper:]' '[:lower:]')
if [[ -e "$output" && $force -ne 1 ]]; then
  echo "Refusing to overwrite $output; pass --force" >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }
random_hex() { openssl rand -hex 32; }
mkdir -p "$(dirname "$output")"
tmp=$(mktemp "$(dirname "$output")/.buzz.env.XXXXXX")
{
  cat "$shared_env"
  cat <<EOF
APP_URL=https://buzz.con.fyi
BUZZ_IMAGE=ghcr.io/block/buzz@sha256:12763e38fd99fe8f4e63466a08ea8e3afbda4da0ebd1f51f0b57d78f9b082abe
RELAY_URL=wss://buzz.con.fyi
BUZZ_MEDIA_BASE_URL=https://buzz.con.fyi/media
BUZZ_MEDIA_SERVER_DOMAIN=buzz.con.fyi
BUZZ_CORS_ORIGINS=https://buzz.con.fyi
RELAY_OWNER_PUBKEY=$owner_pubkey
BUZZ_RELAY_PRIVATE_KEY=$(random_hex)
BUZZ_GIT_HOOK_HMAC_SECRET=$(random_hex)
RUST_LOG=buzz_relay=info,buzz_db=info,buzz_auth=info,buzz_pubsub=info,tower_http=info
EOF
} > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
echo "Generated $output (secrets not displayed)."
