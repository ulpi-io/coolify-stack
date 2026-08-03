#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
generator_file=${SOCIAL_REPLY_GENERATOR_FILE:-$repo_root/platforms/social-reply/generate-env.sh}

usage() {
  echo "Usage: $0 --check SHA | --apply SHA" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ $# -eq 2 ]] || { usage; exit 2; }
mode=$1
source_sha=$2
[[ "$mode" == --check || "$mode" == --apply ]] || { usage; exit 2; }
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || die "source SHA must be exactly 40 lowercase hexadecimal characters"
[[ -f "$generator_file" && ! -L "$generator_file" ]] || die "SocialReply generator must be a regular, non-symlink file"

line_count=$(grep -Ec '^SOCIAL_REPLY_SOURCE_REF=' "$generator_file" || true)
[[ "$line_count" == 1 ]] || die "expected exactly one SOCIAL_REPLY_SOURCE_REF assignment, found $line_count"

current_ref=$(sed -n 's/^SOCIAL_REPLY_SOURCE_REF=//p' "$generator_file")
[[ "$current_ref" =~ ^[0-9a-f]{40}$ ]] || die "current SOCIAL_REPLY_SOURCE_REF is not an immutable commit SHA"

if [[ "$mode" == --check ]]; then
  if [[ "$current_ref" == "$source_sha" ]]; then
    echo "CHECK PASSED: SocialReply already targets $source_sha"
  else
    echo "CHECK PASSED: SocialReply can be promoted from $current_ref to $source_sha"
  fi
  exit 0
fi

[[ "$current_ref" != "$source_sha" ]] || {
  echo "UNCHANGED: SocialReply already targets $source_sha"
  exit 0
}

file_mode=$(stat -f '%Lp' "$generator_file" 2>/dev/null || stat -c '%a' "$generator_file")
tmp_file=$(mktemp "${generator_file}.XXXXXX")
cleanup() { rm -f "$tmp_file"; }
trap cleanup EXIT

awk -v source_sha="$source_sha" '
  BEGIN { count = 0 }
  /^SOCIAL_REPLY_SOURCE_REF=/ {
    print "SOCIAL_REPLY_SOURCE_REF=" source_sha
    count++
    next
  }
  { print }
  END {
    if (count != 1) {
      exit 42
    }
  }
' "$generator_file" > "$tmp_file" || die "could not update SOCIAL_REPLY_SOURCE_REF"

chmod "$file_mode" "$tmp_file"
mv -f "$tmp_file" "$generator_file"
trap - EXIT

updated_ref=$(sed -n 's/^SOCIAL_REPLY_SOURCE_REF=//p' "$generator_file")
[[ "$updated_ref" == "$source_sha" ]] || die "SocialReply source promotion did not persist"
echo "PROMOTED: SocialReply now targets $source_sha"
