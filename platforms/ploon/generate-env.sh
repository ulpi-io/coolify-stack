#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() { echo "Usage: $0 --shared-env FILE --output FILE [--force]" >&2; }
shared_env=""
output=""
force=0
while (($#)); do
  case "$1" in
    --shared-env) [[ $# -ge 2 ]] || { usage; exit 2; }; shared_env=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || { usage; exit 2; }; output=$2; shift 2 ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done
[[ -n "$shared_env" && -n "$output" ]] || { usage; exit 2; }
[[ -f "$shared_env" ]] || { echo "Shared env not found: $shared_env" >&2; exit 1; }
grep -qx 'PLATFORM_SLUG=ploon' "$shared_env" || { echo "Expected the ploon shared fragment" >&2; exit 1; }
if [[ -e "$output" && $force -ne 1 ]]; then
  echo "Refusing to overwrite $output; pass --force" >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }
random_hex() { openssl rand -hex 32; }
random_base64() { openssl rand -base64 32 | tr -d '\n'; }
mkdir -p "$(dirname "$output")"
tmp=$(mktemp "$(dirname "$output")/.ploon.env.XXXXXX")
{
  cat "$shared_env"
  cat <<EOF
APP_URL=https://www.ploon.ai
GIT_AUTH_TOKEN=
EOF
} > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
echo "Generated $output (secrets not displayed)."
