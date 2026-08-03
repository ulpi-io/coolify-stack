#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

platforms=(kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group lokei albert record-cloud plane postiz nudgra-oss n8n twenty buzz social-reply)

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
    buzz) expected_app_url=https://buzz.con.fyi ;;
    social-reply) expected_app_url=https://api.socialreply.ai ;;
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
grep -Fq '{"name":"web","domain":"https://socialreply.ai"},{"name":"nginx","domain":"https://api.socialreply.ai"},{"name":"reverb","domain":"https://ws.socialreply.ai"}' scripts/create-resources.sh || {
  echo "SocialReply web/API/Reverb domain mapping is missing" >&2
  exit 1
}

for domain_mapping in \
  '{"name":"proxy","domain":"https://pm.con.fyi"}' \
  '{"name":"postiz","domain":"https://post.con.fyi"}' \
  '{"name":"app","domain":"https://ig.con.fyi"}' \
  '{"name":"n8n","domain":"https://workflow.con.fyi"}' \
  '{"name":"twenty","domain":"https://crm.con.fyi"}' \
  '{"name":"relay","domain":"https://buzz.con.fyi"}'
do
  grep -Fq "$domain_mapping" scripts/create-resources.sh || {
    echo "Bare con.fyi domain mapping is missing: $domain_mapping" >&2
    exit 1
  }
done

if rg -n 'www\.(pm|post|ig|workflow|crm|buzz)\.con\.fyi' \
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
  platforms/twenty/compose.yaml \
  platforms/buzz/compose.yaml \
  platforms/social-reply/compose.yaml
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
grep -Fq "DISABLE_REGISTRATION: \${DISABLE_REGISTRATION:-true}" platforms/postiz/compose.yaml || {
  echo "Postiz must allow only the first organization by default" >&2
  exit 1
}

grep -Fq 'BUZZ_REQUIRE_RELAY_MEMBERSHIP: "true"' platforms/buzz/compose.yaml || {
  echo "Buzz must use closed relay membership by default" >&2
  exit 1
}
grep -Fq 'BUZZ_S3_ADDRESSING_STYLE: path' platforms/buzz/compose.yaml || {
  echo "Buzz must use path-style addressing with shared MinIO" >&2
  exit 1
}
grep -Fq 'ghcr.io/block/buzz@sha256:12763e38fd99fe8f4e63466a08ea8e3afbda4da0ebd1f51f0b57d78f9b082abe' platforms/buzz/generate-env.sh || {
  echo "Buzz must use the verified immutable upstream image digest" >&2
  exit 1
}
# Match literal Compose-time escaping, not shell variables.
# shellcheck disable=SC2016
grep -Fq 'user buzz on >$$BUZZ_QUEUE_PASSWORD ~buzz:* &buzz:* +@all' infrastructure/compose.yaml || {
  echo "Shared Redis must restrict Buzz to buzz-prefixed keys and channels" >&2
  exit 1
}
# shellcheck disable=SC2016
grep -Fq 'provision buzz-media "$$BUZZ_S3_ACCESS_KEY" "$$BUZZ_S3_SECRET_KEY"' infrastructure/compose.yaml || {
  echo "Shared MinIO must provision Buzz's isolated media bucket" >&2
  exit 1
}
# SocialReply requires its locked PostgreSQL 17 + pgvector contract rather than
# silently targeting the shared PostgreSQL 16 service.
grep -Fq 'pgvector/pgvector@sha256:3e8b3adfd27b5707128f60956f62a793c3c9326ea8cfaf0eab7adccb5d700b21' platforms/social-reply/generate-env.sh || {
  echo "SocialReply must pin the verified PostgreSQL 17 plus pgvector image" >&2
  exit 1
}
grep -Fq 'SOCIAL_REPLY_SOURCE_REF=09c0b41b363ee27071c0ad1e1a5e6d4b11d6cc2e' platforms/social-reply/generate-env.sh || {
  echo "SocialReply must pin the audited source commit" >&2
  exit 1
}
# shellcheck disable=SC2016
grep -Fq '$application->settings->inject_build_args_to_dockerfile=false' scripts/create-resources.sh || {
  echo "SocialReply creation must disable Coolify 4.1.2 Dockerfile build-arg injection" >&2
  exit 1
}
grep -Fq 'command: ["php", "artisan", "migrate", "--force", "--no-interaction"]' platforms/social-reply/compose.yaml || {
  echo "SocialReply must run one release migration service" >&2
  exit 1
}
[[ $(grep -Fc 'dockerfile_inline: *api-dockerfile' platforms/social-reply/compose.yaml) == 2 ]] || {
  echo "SocialReply API and nginx builds must inline the pinned upstream production stages for Coolify compatibility" >&2
  exit 1
}
[[ $(grep -Fc '<<: [*service-defaults, *api-image]' platforms/social-reply/compose.yaml) == 1 ]] || {
  echo "SocialReply must build its shared API runtime image exactly once" >&2
  exit 1
}
[[ $(grep -Fc '<<: [*service-defaults, *api-runtime-image]' platforms/social-reply/compose.yaml) == 4 ]] || {
  echo "SocialReply one-shot and worker services must reuse the API runtime image without duplicated builds" >&2
  exit 1
}
grep -Fq 'dockerfile_inline: *web-dockerfile' platforms/social-reply/compose.yaml || {
  echo "SocialReply web build must inline the pinned upstream Dockerfile for Coolify compatibility" >&2
  exit 1
}
# shellcheck disable=SC2016
grep -Fq 'user social-reply on >$$SOCIAL_REPLY_QUEUE_PASSWORD ~social-reply:* &social-reply:* +@all' infrastructure/compose.yaml || {
  echo "Shared Redis must restrict SocialReply to social-reply-prefixed keys and channels" >&2
  exit 1
}
# shellcheck disable=SC2016
grep -Fq 'provision social-reply "$$SOCIAL_REPLY_S3_ACCESS_KEY" "$$SOCIAL_REPLY_S3_SECRET_KEY"' infrastructure/compose.yaml || {
  echo "Shared MinIO must provision SocialReply's isolated bucket" >&2
  exit 1
}

compose_count=$(find infrastructure platforms -type f -name compose.yaml | wc -l | tr -d ' ')
generator_count=$(find infrastructure platforms -type f -name generate-env.sh | wc -l | tr -d ' ')
[[ "$compose_count" = 19 ]] || { echo "Expected 19 Compose files, found $compose_count" >&2; exit 1; }
[[ "$generator_count" = 19 ]] || { echo "Expected 19 env generators, found $generator_count" >&2; exit 1; }

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
[[ "$fragment_count" = 18 ]] || { echo "Expected 18 shared fragments, found $fragment_count" >&2; exit 1; }

docker compose --env-file "$validation_dir/infrastructure.env" -f infrastructure/compose.yaml config -q

for slug in "${platforms[@]}"; do
  env_file="$validation_dir/$slug.env"
  generator_args=(
    --shared-env "$validation_dir/platforms/$slug.shared.env"
    --output "$env_file"
  )
  if [[ "$slug" == buzz ]]; then
    generator_args+=(--owner-pubkey 79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)
  fi
  "platforms/$slug/generate-env.sh" "${generator_args[@]}" >/dev/null
  [[ $(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file") = 600 ]] || {
    echo "$env_file is not mode 0600" >&2
    exit 1
  }
  GIT_AUTH_TOKEN=${GIT_AUTH_TOKEN:-validation-only} docker compose --env-file "$env_file" -f "platforms/$slug/compose.yaml" config -q
  if [[ "$slug" == social-reply ]]; then
    compose_payload_bytes=$(GIT_AUTH_TOKEN=${GIT_AUTH_TOKEN:-validation-only} docker compose --env-file "$env_file" -f "platforms/$slug/compose.yaml" config | base64 | wc -c | tr -d ' ')
    (( compose_payload_bytes < 120000 )) || {
      echo "SocialReply's encoded Compose payload is $compose_payload_bytes bytes; Coolify 4.1.2 requires less than 120000" >&2
      exit 1
    }
  fi
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

echo "Validated 19 Compose files, 19 generators, and 18 platform fragments."
