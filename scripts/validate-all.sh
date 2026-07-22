#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

platforms=(kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group lokei albert record-cloud plane postiz nudgra-oss n8n twenty)

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
docker compose version >/dev/null

[[ -f infrastructure/compose.yaml && -x infrastructure/generate-env.sh ]] || {
  echo "Infrastructure Compose/generator pair is missing" >&2
  exit 1
}

for slug in "${platforms[@]}"; do
  [[ -f "platforms/$slug/compose.yaml" && -x "platforms/$slug/generate-env.sh" ]] || {
    echo "Missing Compose/generator pair for $slug" >&2
    exit 1
  }
done

compose_count=$(find infrastructure platforms -type f -name compose.yaml | wc -l | tr -d ' ')
generator_count=$(find infrastructure platforms -type f -name generate-env.sh | wc -l | tr -d ' ')
[[ "$compose_count" = 17 ]] || { echo "Expected 17 Compose files, found $compose_count" >&2; exit 1; }
[[ "$generator_count" = 17 ]] || { echo "Expected 17 env generators, found $generator_count" >&2; exit 1; }

bash -n infrastructure/generate-env.sh platforms/*/generate-env.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck infrastructure/generate-env.sh platforms/*/generate-env.sh
else
  echo "WARNING: shellcheck is not installed; skipped shell lint" >&2
fi

validation_dir=$(mktemp -d)
cleanup() { rm -rf "$validation_dir"; }
trap cleanup EXIT

infrastructure/generate-env.sh --output-dir "$validation_dir" >/dev/null
fragment_count=$(find "$validation_dir/platforms" -type f -name '*.shared.env' | wc -l | tr -d ' ')
[[ "$fragment_count" = 16 ]] || { echo "Expected 16 shared fragments, found $fragment_count" >&2; exit 1; }

docker compose --env-file "$validation_dir/infrastructure.env" -f infrastructure/compose.yaml config -q

for slug in "${platforms[@]}"; do
  env_file="$validation_dir/$slug.env"
  "platforms/$slug/generate-env.sh" \
    --shared-env "$validation_dir/platforms/$slug.shared.env" \
    --output "$env_file" >/dev/null
  [[ $(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file") = 600 ]] || {
    echo "$env_file is not mode 0600" >&2
    exit 1
  }
  docker compose --env-file "$env_file" -f "platforms/$slug/compose.yaml" config -q
  while IFS= read -r service; do
    case "$service" in
      mysql|postgres|postgresql|redis|valkey|valkey-cache|valkey-queue|minio|qdrant|rabbitmq|elasticsearch|temporal|mailpit)
        echo "Platform $slug duplicates shared service $service" >&2
        exit 1
        ;;
    esac
  done < <(docker compose --env-file "$env_file" -f "platforms/$slug/compose.yaml" config --services)
done

if rg -n 'example\.invalid|:latest([[:space:]]|$)' "$validation_dir" >/dev/null; then
  echo "WARNING: generated platform env files still contain image placeholders or mutable tags." >&2
fi

echo "Validated 17 Compose files, 17 generators, and 16 platform fragments."
