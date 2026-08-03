#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
promoter="$repo_root/scripts/promote-social-reply-ref.sh"
test_dir=$(mktemp -d)
cleanup() { rm -rf "$test_dir"; }
trap cleanup EXIT

old_sha=1111111111111111111111111111111111111111
new_sha=2222222222222222222222222222222222222222
generator="$test_dir/generate-env.sh"

printf '#!/usr/bin/env bash\nSOCIAL_REPLY_SOURCE_REF=%s\nUNCHANGED=value\n' "$old_sha" > "$generator"
chmod 755 "$generator"

SOCIAL_REPLY_GENERATOR_FILE="$generator" "$promoter" --check "$new_sha" >/dev/null
SOCIAL_REPLY_GENERATOR_FILE="$generator" "$promoter" --apply "$new_sha" >/dev/null
grep -qx "SOCIAL_REPLY_SOURCE_REF=$new_sha" "$generator"
grep -qx 'UNCHANGED=value' "$generator"
[[ $(stat -f '%Lp' "$generator" 2>/dev/null || stat -c '%a' "$generator") == 755 ]]

if SOCIAL_REPLY_GENERATOR_FILE="$generator" "$promoter" --check main >/dev/null 2>&1; then
  echo "invalid mutable ref unexpectedly passed" >&2
  exit 1
fi

printf 'SOCIAL_REPLY_SOURCE_REF=%s\nSOCIAL_REPLY_SOURCE_REF=%s\n' "$old_sha" "$new_sha" > "$generator"
if SOCIAL_REPLY_GENERATOR_FILE="$generator" "$promoter" --check "$new_sha" >/dev/null 2>&1; then
  echo "duplicate source assignments unexpectedly passed" >&2
  exit 1
fi

echo "SocialReply CD promotion tests passed."
