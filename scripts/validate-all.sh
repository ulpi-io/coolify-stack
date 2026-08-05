#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

platforms=(kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group con-fyi lokei albert record-cloud plane postiz nudgra-oss n8n twenty buzz social-reply qm)

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
    con-fyi) expected_app_url=https://con.fyi ;;
    nudgra-oss) expected_app_url=https://ig.con.fyi ;;
    n8n) expected_app_url=https://workflow.con.fyi ;;
    twenty) expected_app_url=https://crm.con.fyi ;;
    buzz) expected_app_url=https://buzz.con.fyi ;;
    social-reply) expected_app_url=https://api.socialreply.ai ;;
    qm) expected_app_url=https://agents.con.fyi ;;
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
grep -Fq '{"name":"web","domain":"https://www.socialreply.ai"},{"name":"redirect","domain":"https://socialreply.ai"},{"name":"nginx","domain":"https://api.socialreply.ai"},{"name":"reverb","domain":"https://ws.socialreply.ai"}' scripts/create-resources.sh || {
  echo "SocialReply canonical web/apex redirect/API/Reverb domain mapping is missing" >&2
  exit 1
}
grep -Fq 'APP_FRONTEND_URL=https://www.socialreply.ai' platforms/social-reply/generate-env.sh || {
  echo "SocialReply must use www.socialreply.ai as its canonical frontend origin" >&2
  exit 1
}
# Match the literal nginx request URI variable.
# shellcheck disable=SC2016
grep -Fq 'return 301 https://www.socialreply.ai$request_uri;' platforms/social-reply/apex-redirect.conf || {
  echo "SocialReply apex must permanently redirect to the canonical www host" >&2
  exit 1
}
grep -Fq 'traefik.http.middlewares.socialreply-force-https.redirectscheme.permanent: "true"' platforms/social-reply/compose.yaml || {
  echo "SocialReply HTTP routes must permanently redirect to HTTPS" >&2
  exit 1
}
for socialreply_router in apex www api ws; do
  grep -Fq "traefik.http.routers.socialreply-${socialreply_router}-http.priority: \"10000\"" platforms/social-reply/compose.yaml || {
    echo "SocialReply ${socialreply_router} HTTP redirect router must outrank Coolify's generated router" >&2
    exit 1
  }
done
[[ $(grep -Fc 'priority: "10000"' platforms/social-reply/compose.yaml) == 4 ]] || {
  echo "SocialReply HTTP redirect routers must outrank Coolify's generated routers" >&2
  exit 1
}
grep -Fq 'REVERB_SCALING_ENABLED: "false"' platforms/social-reply/compose.yaml || {
  echo "Single-instance SocialReply Reverb must not enable Redis horizontal scaling" >&2
  exit 1
}
# Match the literal shell condition in the resource creator.
# shellcheck disable=SC2016
grep -Fq '[[ "$slug" == con-fyi || "$slug" == social-reply ]] && force_https_enabled=false' scripts/create-resources.sh || {
  echo "SocialReply must own its permanent redirects instead of Coolify's generic middleware" >&2
  exit 1
}
grep -Fq '{"name":"portal","domain":"https://agents.con.fyi"}' scripts/create-resources.sh || {
  echo "QM portal domain mapping is missing" >&2
  exit 1
}
grep -Fq '{"name":"web","domain":"https://con.fyi"}' scripts/create-resources.sh || {
  echo "ConFYI web domain mapping is missing" >&2
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
  platforms/social-reply/compose.yaml \
  platforms/qm/compose.yaml
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
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'FACEBOOK_APP_ID: ${FACEBOOK_APP_ID:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional Facebook app ID into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'FACEBOOK_APP_SECRET: ${FACEBOOK_APP_SECRET:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional Facebook app secret into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'INSTAGRAM_APP_ID: ${INSTAGRAM_APP_ID:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional standalone Instagram app ID into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'INSTAGRAM_APP_SECRET: ${INSTAGRAM_APP_SECRET:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional standalone Instagram app secret into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'YOUTUBE_CLIENT_ID: ${YOUTUBE_CLIENT_ID:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional YouTube OAuth client ID into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'YOUTUBE_CLIENT_SECRET: ${YOUTUBE_CLIENT_SECRET:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional YouTube OAuth client secret into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'TIKTOK_CLIENT_ID: ${TIKTOK_CLIENT_ID:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional TikTok OAuth client ID into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'TIKTOK_CLIENT_SECRET: ${TIKTOK_CLIENT_SECRET:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional TikTok OAuth client secret into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'LINKEDIN_CLIENT_ID: ${LINKEDIN_CLIENT_ID:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional LinkedIn OAuth client ID into its provider runtime" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'LINKEDIN_CLIENT_SECRET: ${LINKEDIN_CLIENT_SECRET:-}' platforms/postiz/compose.yaml || {
  echo "Postiz must pass the optional LinkedIn OAuth client secret into its provider runtime" >&2
  exit 1
}

grep -Fq 'BUZZ_REQUIRE_RELAY_MEMBERSHIP: "true"' platforms/buzz/compose.yaml || {
  echo "Buzz must use closed relay membership by default" >&2
  exit 1
}
grep -Fq 'BUZZ_CORS_ORIGINS=https://buzz.con.fyi,tauri://localhost,http://tauri.localhost' platforms/buzz/generate-env.sh || {
  echo "Buzz must allow its web and packaged desktop origins" >&2
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
# Every PostgreSQL consumer shares the pinned PostgreSQL 17 + pgvector service.
grep -Fq 'pgvector/pgvector@sha256:3e8b3adfd27b5707128f60956f62a793c3c9326ea8cfaf0eab7adccb5d700b21' infrastructure/compose.yaml || {
  echo "Shared infrastructure must pin the verified PostgreSQL 17 plus pgvector image" >&2
  exit 1
}
grep -Fq 'postgresql17-data:/var/lib/postgresql/data' infrastructure/compose.yaml || {
  echo "PostgreSQL 17 must use its distinct migrated data-volume key" >&2
  exit 1
}
# shellcheck disable=SC2016
grep -Fq 'create_tenant socialreply socialreply "$$SOCIAL_REPLY_DB_PASSWORD"' infrastructure/compose.yaml || {
  echo "Shared PostgreSQL bootstrap must provision SocialReply's isolated database and role" >&2
  exit 1
}
grep -Fq "psql -d socialreply -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS vector'" infrastructure/compose.yaml || {
  echo "Shared PostgreSQL bootstrap must enable pgvector only in SocialReply's database" >&2
  exit 1
}
if grep -Fq 'social-reply-postgres' platforms/social-reply/compose.yaml; then
  echo "SocialReply must not duplicate the shared PostgreSQL service" >&2
  exit 1
fi
grep -Eq '^SOCIAL_REPLY_SOURCE_REF=[0-9a-f]{40}$' platforms/social-reply/generate-env.sh || {
  echo "SocialReply must pin one immutable source commit SHA" >&2
  exit 1
}
grep -Fq 'docker-php-ext-install -j2' platforms/social-reply/compose.yaml || {
  echo "SocialReply must bound PHP extension compilation on the shared production host" >&2
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

# shellcheck disable=SC2016
grep -Fq 'create_tenant qm qm "$$QM_DB_PASSWORD"' infrastructure/compose.yaml || {
  echo "Shared PostgreSQL bootstrap must provision QM's isolated database and role" >&2
  exit 1
}
if rg -n '^  (postgres|postgresql):' platforms/qm/compose.yaml >/dev/null; then
  echo "QM must reuse shared PostgreSQL 17" >&2
  exit 1
fi
grep -Eq '^QM_SOURCE_REF=[0-9a-f]{40}$' platforms/qm/generate-env.sh || {
  echo "QM must pin one immutable private-fork source commit SHA" >&2
  exit 1
}
# Match the literal generator interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'ADMIN_GRANTS=$admin_email:org_admin' platforms/qm/generate-env.sh || {
  echo "QM must keep organization administration scoped to the configured administrator" >&2
  exit 1
}
# Match the literal generator interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'AUTH_ALLOWED_EMAILS=$admin_email,tania@opengrowthgroup.co' platforms/qm/generate-env.sh || {
  echo "QM must allow Cip and Tania to sign in" >&2
  exit 1
}
grep -Fq 'AUTH_EMAIL_FROM=Agents <no-reply@agents.con.fyi>' platforms/qm/generate-env.sh || {
  echo "QM must send sign-in email from the Agents domain" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'context: https://github.com/ulpi-io/qm.git#${QM_SOURCE_REF:?required}' platforms/qm/compose.yaml || {
  echo "QM must build from the private ulpi-io source ref" >&2
  exit 1
}
grep -Fq 'image: docker:29-dind@sha256:084e385b0c9b7ab35d5a46dfedd033721448c000dbec71adcf13da8a9e71baa8' platforms/qm/compose.yaml || {
  echo "QM must pin its dedicated Docker-in-Docker image" >&2
  exit 1
}
grep -Fq 'privileged: true' platforms/qm/compose.yaml || {
  echo "QM local sandboxes require the explicitly approved privileged DinD service" >&2
  exit 1
}
grep -Fq 'image: haproxy:3.2-alpine@sha256:79799e8b2977e60802774fa53d29e6b54e045402cdd8a8b9fe43923e7095a047' platforms/qm/compose.yaml || {
  echo "QM must pin its PostgreSQL network proxy image" >&2
  exit 1
}
grep -Fq 'networks: [internal, shared]' platforms/qm/compose.yaml || {
  echo "QM's PostgreSQL proxy must bridge only its internal and shared networks" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq '@postgres-proxy:${DB_PORT:?required}' platforms/qm/compose.yaml || {
  echo "QM core must reach shared PostgreSQL only through its internal proxy" >&2
  exit 1
}
grep -Fq -- '--host=tcp://127.0.0.1:2375' platforms/qm/compose.yaml || {
  echo "QM's private Docker daemon must listen only on loopback" >&2
  exit 1
}
if grep -Eq '^\s*-\s*/var/run/docker\.sock:' platforms/qm/compose.yaml; then
  echo "QM must not mount the production host Docker socket" >&2
  exit 1
fi
[[ $(grep -Fc 'network_mode: service:sandbox-docker' platforms/qm/compose.yaml) == 2 ]] || {
  echo "Only QM core and its one-shot builder may share the private Docker network namespace" >&2
  exit 1
}
if sed -n '/^  core:/,/^  web-ui:/p' platforms/qm/compose.yaml | grep -Eq '^    (expose|ports):'; then
  echo "QM core must not publish or expose ports while sharing the DinD network namespace" >&2
  exit 1
fi
if sed -n '/^  sandbox-docker:/,/^  sandbox-builder:/p' platforms/qm/compose.yaml | grep -Eq '^      shared:'; then
  echo "QM's privileged DinD service must not attach directly to the shared network" >&2
  exit 1
fi
grep -Fq 'HARNESS: claude' platforms/qm/compose.yaml || {
  echo "QM must use the approved Claude harness" >&2
  exit 1
}
# Match the literal Compose-time interpolation expression.
# shellcheck disable=SC2016
grep -Fq 'CLAUDE_CODE_OAUTH_TOKEN: ${CLAUDE_CODE_OAUTH_TOKEN:?required}' platforms/qm/compose.yaml || {
  echo "QM must inject the Claude subscription token into core" >&2
  exit 1
}
if rg -n '^\s+(MODEL_PROVIDER|ANTHROPIC_API_KEY):' platforms/qm/compose.yaml >/dev/null; then
  echo "QM must not override Claude subscription authentication with an Anthropic API key" >&2
  exit 1
fi
grep -Fq 'aliases: [qm-auth.internal]' platforms/qm/compose.yaml || {
  echo "QM's built-in auth broker must use a production-safe private-network hostname" >&2
  exit 1
}
[[ $(grep -Fc 'http://qm-auth.internal:8080' platforms/qm/compose.yaml) == 4 ]] || {
  echo "QM portal must use the private auth-broker origin for every server-side OIDC endpoint" >&2
  exit 1
}
grep -Fq 'process.env.CLAUDE_CODE_OAUTH_TOKEN' platforms/qm/compose.yaml || {
  echo "QM must recognize Claude subscription auth in its portal readiness check" >&2
  exit 1
}
# Match the literal create-resource shell condition.
# shellcheck disable=SC2016
grep -Fq 'if [[ "$slug" == social-reply || "$slug" == qm ]]' scripts/create-resources.sh || {
  echo "QM creation must disable Coolify 4.1.2 Dockerfile build-arg injection" >&2
  exit 1
}

compose_count=$(find infrastructure platforms -type f -name compose.yaml | wc -l | tr -d ' ')
generator_count=$(find infrastructure platforms -type f -name generate-env.sh | wc -l | tr -d ' ')
[[ "$compose_count" = 21 ]] || { echo "Expected 21 Compose files, found $compose_count" >&2; exit 1; }
[[ "$generator_count" = 21 ]] || { echo "Expected 21 env generators, found $generator_count" >&2; exit 1; }

bash -n infrastructure/generate-env.sh platforms/*/generate-env.sh scripts/*.sh \
  scripts/server/redeploy-compose-service \
  scripts/tests/redeploy-compose-service.test.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck infrastructure/generate-env.sh platforms/*/generate-env.sh scripts/*.sh \
    scripts/server/redeploy-compose-service \
    scripts/tests/redeploy-compose-service.test.sh
else
  echo "WARNING: shellcheck is not installed; skipped shell lint" >&2
fi

scripts/tests/redeploy-compose-service.test.sh >/dev/null

validation_dir=$(mktemp -d)
cleanup() { rm -rf "$validation_dir"; }
trap cleanup EXIT

infrastructure/generate-env.sh --output-dir "$validation_dir" >/dev/null
fragment_count=$(find "$validation_dir/platforms" -type f -name '*.shared.env' | wc -l | tr -d ' ')
[[ "$fragment_count" = 20 ]] || { echo "Expected 20 shared fragments, found $fragment_count" >&2; exit 1; }

qm_validation_token_file="$validation_dir/qm-validation-claude-token"
qm_validation_resend_file="$validation_dir/qm-validation-resend-key"
printf '%s' 'validation-only-claude-token-00000000000000000000000000000000' > "$qm_validation_token_file"
printf '%s' 'validation-only-resend-key-000000000000000000000000000000000' > "$qm_validation_resend_file"
chmod 600 "$qm_validation_token_file" "$qm_validation_resend_file"

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
  if [[ "$slug" == qm ]]; then
    generator_args+=(--claude-token-file "$qm_validation_token_file" --resend-key-file "$qm_validation_resend_file")
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

echo "Validated 21 Compose files, 21 generators, and 20 platform fragments."
