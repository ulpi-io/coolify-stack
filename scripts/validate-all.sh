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

for generator in platforms/*/generate-env.sh; do
  slug=$(basename "$(dirname "$generator")")
  app_url=$(grep '^APP_URL=' "$generator" | head -1 | cut -d= -f2-)
  case "$slug" in
    plane) expected_app_url=https://pm.con.fyi ;;
    postiz) expected_app_url=https://post.con.fyi ;;
    nudgra-oss) expected_app_url=https://ig.con.fyi ;;
    n8n) expected_app_url=https://workflow.con.fyi ;;
    twenty) expected_app_url=https://crm.con.fyi ;;
    *) expected_app_url='https://www.*' ;;
  esac
  if [[ "$expected_app_url" = 'https://www.*' ]]; then
    [[ "$app_url" == https://www.* ]] || {
      echo "$generator must use a canonical https://www.* APP_URL" >&2
      exit 1
    }
  else
    [[ "$app_url" = "$expected_app_url" ]] || {
      echo "$generator must use APP_URL=$expected_app_url" >&2
      exit 1
    }
  fi
  api_url=$(grep '^API_PUBLIC_URL=' "$generator" | head -1 | cut -d= -f2- || true)
  [[ -z "$api_url" || "$api_url" == https://api.* ]] || {
    echo "$generator must use a canonical https://api.* API_PUBLIC_URL" >&2
    exit 1
  }
done

grep -Fq '{"name":"dashboard","domain":"https://www.clavinci.com"},{"name":"api","domain":"https://api.clavinci.com"}' scripts/create-resources.sh || {
  echo "Clavinci web/API domain mapping is missing" >&2
  exit 1
}
grep -Fq '{"name":"web","domain":"https://www.albert.con.fyi"},{"name":"nginx","domain":"https://api.albert.con.fyi"}' scripts/create-resources.sh || {
  echo "Albert web/API domain mapping is missing" >&2
  exit 1
}

for domain_mapping in \
  '{"name":"proxy","domain":"https://pm.con.fyi"}' \
  '{"name":"postiz","domain":"https://post.con.fyi"}' \
  '{"name":"app","domain":"https://ig.con.fyi"}' \
  '{"name":"n8n","domain":"https://workflow.con.fyi"}' \
  '{"name":"twenty","domain":"https://crm.con.fyi"}'
do
  grep -Fq "$domain_mapping" scripts/create-resources.sh || {
    echo "Bare con.fyi domain mapping is missing: $domain_mapping" >&2
    exit 1
  }
done

if rg -n 'www\.(pm|post|ig|workflow|crm)\.con\.fyi' \
  README.md REPOSITORIES.md COOLIFY_IMPORT.md DIGITALOCEAN_SERVER.md \
  infrastructure platforms scripts >/dev/null; then
  echo "A retired www-prefixed con.fyi platform domain is still present" >&2
  exit 1
fi

grep -Fq 'is_container_label_escape_enabled:false' scripts/create-resources.sh || {
  echo "Coolify Compose resources must allow trusted network-label interpolation" >&2
  exit 1
}
for compose_file in \
  platforms/plane/compose.yaml \
  platforms/postiz/compose.yaml \
  platforms/nudgra-oss/compose.yaml \
  platforms/n8n/compose.yaml \
  platforms/twenty/compose.yaml
do
  # Match the literal Compose-time interpolation expression.
  # shellcheck disable=SC2016
  grep -Fq 'traefik.docker.network: ${COOLIFY_RESOURCE_UUID:-}' "$compose_file" || {
    echo "$compose_file must pin Traefik to the Coolify resource network" >&2
    exit 1
  }
done

if ! grep -Fq 'temporal-namespace-bootstrap:' infrastructure/compose.yaml ||
  ! grep -Fq 'namespace create --namespace postiz' infrastructure/compose.yaml
then
  echo "Infrastructure must create the Postiz Temporal namespace idempotently" >&2
  exit 1
fi
grep -Fq 'Promise.all([c(5000),c(3000)])' platforms/postiz/compose.yaml || {
  echo "Postiz healthcheck must cover both frontend and backend ports" >&2
  exit 1
}

compose_count=$(find infrastructure platforms -type f -name compose.yaml | wc -l | tr -d ' ')
generator_count=$(find infrastructure platforms -type f -name generate-env.sh | wc -l | tr -d ' ')
[[ "$compose_count" = 17 ]] || { echo "Expected 17 Compose files, found $compose_count" >&2; exit 1; }
[[ "$generator_count" = 17 ]] || { echo "Expected 17 env generators, found $generator_count" >&2; exit 1; }

bash -n infrastructure/generate-env.sh platforms/*/generate-env.sh scripts/*.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck infrastructure/generate-env.sh platforms/*/generate-env.sh scripts/*.sh
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
  GIT_AUTH_TOKEN=${GIT_AUTH_TOKEN:-validation-only} docker compose --env-file "$env_file" -f "platforms/$slug/compose.yaml" config -q
  while IFS= read -r service; do
    case "$service" in
      mysql|postgres|postgresql|redis|valkey|valkey-cache|valkey-queue|minio|qdrant|rabbitmq|elasticsearch|temporal|mailpit)
        echo "Platform $slug duplicates shared service $service" >&2
        exit 1
        ;;
    esac
  done < <(GIT_AUTH_TOKEN=${GIT_AUTH_TOKEN:-validation-only} docker compose --env-file "$env_file" -f "platforms/$slug/compose.yaml" config --services)
done

if rg -n ':(latest|stable)([[:space:]]|$)' "$validation_dir" >/dev/null; then
  echo "A published image still uses a mutable latest or stable tag." >&2
  exit 1
fi

echo "Validated 17 Compose files, 17 generators, and 16 platform fragments."
