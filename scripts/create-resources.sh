#!/usr/bin/env bash
set -euo pipefail

umask 077

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

coolify_host=${COOLIFY_HOST:-68.183.135.86}
coolify_user=${COOLIFY_USER:-root}
server_uuid=${COOLIFY_SERVER_UUID:-gxazsje7tdtphinl8zu8k1cr}
repository_url=${COOLIFY_REPOSITORY_URL:-https://github.com/ulpi-io/coolify-stack.git}
operator_email=${OPERATOR_EMAIL:-cip@opengrowthgroup.co}
buzz_owner_pubkey=""
ssh_key=${COOLIFY_SSH_KEY:-}
mode=""
reset=0
only_slug=""
provided_env_file=""
qm_claude_token_file=""
qm_resend_key_file=""
token_name=ogg-coolify-stack-bootstrap
token_file=/tmp/ogg-coolify-stack-token
legacy_token_name=codex-coolify-stack-bootstrap
legacy_token_file=/tmp/codex-coolify-stack-token
work_dir=""
token_created=0
api_managed=0

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/create-resources.sh --check
  scripts/create-resources.sh --apply --reset --ssh-key PATH
  scripts/create-resources.sh --apply --only SLUG --env-file FILE --ssh-key PATH

Options:
  --check             Generate and validate all environment artifacts locally only.
  --apply             Configure Coolify. This never deploys an application.
  --reset             Delete and recreate the selected exact stack project(s).
  --only SLUG         Create one missing resource without touching other projects.
  --env-file FILE     Use a pre-generated mode-0600 env file with --only.
  --qm-claude-token-file FILE
                     Mode-0600 Claude setup-token file used when generating QM.
  --qm-resend-key-file FILE
                     Mode-0600 Resend API-key file used when generating QM.
  --ssh-key PATH      SSH private key used for the Coolify host.
  --host HOST         Coolify server SSH host (default: 68.183.135.86).
  --server-uuid UUID  Coolify destination server UUID.
  --operator-email E  Nudgra operator email allowlist value.
  --buzz-owner-pubkey HEX
                     64-character hex Nostr public key bootstrapped as Buzz owner.
  --repository URL    Git repository containing these Compose files.

Before --apply, restrict Coolify API Allowed IPs to exactly:
127.0.0.1,::1
The script opens the API for localhost only and closes it on exit.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --check) mode=check; shift ;;
    --apply) mode=apply; shift ;;
    --reset) reset=1; shift ;;
    --only) [[ $# -ge 2 ]] || die "--only needs a slug"; only_slug=$2; shift 2 ;;
    --env-file) [[ $# -ge 2 ]] || die "--env-file needs a path"; provided_env_file=$2; shift 2 ;;
    --qm-claude-token-file) [[ $# -ge 2 ]] || die "--qm-claude-token-file needs a path"; qm_claude_token_file=$2; shift 2 ;;
    --qm-resend-key-file) [[ $# -ge 2 ]] || die "--qm-resend-key-file needs a path"; qm_resend_key_file=$2; shift 2 ;;
    --ssh-key) [[ $# -ge 2 ]] || die "--ssh-key needs a path"; ssh_key=$2; shift 2 ;;
    --host) [[ $# -ge 2 ]] || die "--host needs a value"; coolify_host=$2; shift 2 ;;
    --server-uuid) [[ $# -ge 2 ]] || die "--server-uuid needs a value"; server_uuid=$2; shift 2 ;;
    --operator-email) [[ $# -ge 2 ]] || die "--operator-email needs a value"; operator_email=$2; shift 2 ;;
    --buzz-owner-pubkey) [[ $# -ge 2 ]] || die "--buzz-owner-pubkey needs a value"; buzz_owner_pubkey=$2; shift 2 ;;
    --repository) [[ $# -ge 2 ]] || die "--repository needs a value"; repository_url=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "$mode" ]] || { usage; exit 2; }
[[ "$operator_email" == *@* ]] || die "--operator-email must be an email address"
if [[ "$mode" == apply && ( -z "$only_slug" || "$only_slug" == buzz ) ]]; then
  [[ "$buzz_owner_pubkey" =~ ^[[:xdigit:]]{64}$ ]] || die "--apply requires --buzz-owner-pubkey with a 64-character hex Nostr public key"
elif [[ -z "$buzz_owner_pubkey" ]]; then
  # Public key for secret scalar 1. It is used only in throwaway --check output.
  buzz_owner_pubkey=79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798
else
  [[ "$buzz_owner_pubkey" =~ ^[[:xdigit:]]{64}$ ]] || die "--buzz-owner-pubkey must be a 64-character hex Nostr public key"
fi

platforms=(kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group con-fyi lokei albert record-cloud plane postiz nudgra-oss n8n twenty buzz social-reply qm)

# slug|project|compose path|resource|domains JSON|description
stacks=(
  'infrastructure|Shared Infrastructure|/infrastructure/compose.yaml|Shared Infrastructure Stack|[]|Shared production infrastructure for all OGG platforms.'
  'kensi-ai|Kensi AI|/platforms/kensi-ai/compose.yaml|Kensi AI Stack|[{"name":"web","domain":"https://www.kensi.ai"},{"name":"nginx","domain":"https://api.kensi.ai"}]|Production Kensi AI web and API stack.'
  'agentshq|AgentsHQ|/platforms/agentshq/compose.yaml|AgentsHQ Stack|[{"name":"web","domain":"https://www.agentshq.sh"},{"name":"api","domain":"https://api.agentshq.sh"}]|Production AgentsHQ web and API stack.'
  'open-kudos|TeamToast|/platforms/open-kudos/compose.yaml|TeamToast Stack|[{"name":"web","domain":"https://www.teamtoast.ai"},{"name":"nginx","domain":"https://api.teamtoast.ai"}]|Production TeamToast web and Open Kudos API stack.'
  'insight|Clavinci|/platforms/insight/compose.yaml|Clavinci Stack|[{"name":"dashboard","domain":"https://www.clavinci.com"},{"name":"api","domain":"https://api.clavinci.com"}]|Production Clavinci dashboard and API stack.'
  'togglebox|Togglebox|/platforms/togglebox/compose.yaml|Togglebox Stack|[{"name":"admin","domain":"https://www.togglebox.dev"},{"name":"api","domain":"https://api.togglebox.dev"}]|Production Togglebox admin and API stack.'
  'openpay|OpenPay|/platforms/openpay/compose.yaml|OpenPay Stack|[{"name":"web","domain":"https://www.openpay.fyi"},{"name":"nginx","domain":"https://api.openpay.fyi"}]|Production OpenPay web and API stack.'
  'ploon|Ploon|/platforms/ploon/compose.yaml|Ploon Stack|[{"name":"web","domain":"https://www.ploon.ai"}]|Production Ploon web stack.'
  'open-growth-group|Open Growth Group|/platforms/open-growth-group/compose.yaml|Open Growth Group Stack|[{"name":"web","domain":"https://www.opengrowthgroup.co"}]|Production Open Growth Group website stack.'
  'con-fyi|ConFYI|/platforms/con-fyi/compose.yaml|ConFYI Stack|[{"name":"web","domain":"https://con.fyi"}]|Public product information and legal pages for ConFYI services.'
  'lokei|Lokei|/platforms/lokei/compose.yaml|Lokei Stack|[{"name":"web","domain":"https://www.lokei.dev"},{"name":"nginx","domain":"https://api.lokei.dev"},{"name":"relay","domain":"https://relay.lokei.dev"}]|Production Lokei web, API, workers, and relay stack.'
  'albert|Albert|/platforms/albert/compose.yaml|Albert Stack|[{"name":"web","domain":"https://www.albert.con.fyi"},{"name":"nginx","domain":"https://api.albert.con.fyi"}]|Production Albert web and API stack.'
  'record-cloud|Record Cloud|/platforms/record-cloud/compose.yaml|Record Cloud Stack|[{"name":"web","domain":"https://www.record.con.fyi"},{"name":"api","domain":"https://api.record.con.fyi"}]|Production Record Cloud web and API stack.'
  'plane|Plane|/platforms/plane/compose.yaml|Plane Stack|[{"name":"proxy","domain":"https://pm.con.fyi"}]|Production Plane project-management stack.'
  'postiz|Postiz|/platforms/postiz/compose.yaml|Postiz Stack|[{"name":"postiz","domain":"https://post.con.fyi"}]|Production Postiz social publishing stack.'
  'nudgra-oss|Nudgra OSS|/platforms/nudgra-oss/compose.yaml|Nudgra OSS Stack|[{"name":"app","domain":"https://ig.con.fyi"}]|Production Nudgra OSS application stack.'
  'n8n|N8N|/platforms/n8n/compose.yaml|N8N Stack|[{"name":"n8n","domain":"https://workflow.con.fyi"}]|Production n8n workflow automation stack.'
  'twenty|Twenty|/platforms/twenty/compose.yaml|Twenty Stack|[{"name":"twenty","domain":"https://crm.con.fyi"}]|Production Twenty CRM stack.'
  'buzz|Buzz|/platforms/buzz/compose.yaml|Buzz Stack|[{"name":"relay","domain":"https://buzz.con.fyi"}]|Production Buzz human-and-agent workspace relay.'
  'social-reply|SocialReply|/platforms/social-reply/compose.yaml|SocialReply Stack|[{"name":"web","domain":"https://socialreply.ai"},{"name":"nginx","domain":"https://api.socialreply.ai"},{"name":"reverb","domain":"https://ws.socialreply.ai"}]|Production SocialReply conversational-marketing platform.'
  'qm|QM Agents|/platforms/qm/compose.yaml|QM Stack|[{"name":"portal","domain":"https://agents.con.fyi"}]|Production QM agent workspace with a private local sandbox daemon.'
)

if [[ -n "$only_slug" ]]; then
  known_slug=0
  for stack in "${stacks[@]}"; do
    IFS='|' read -r slug _ <<<"$stack"
    [[ "$slug" == "$only_slug" ]] && known_slug=1
  done
  [[ $known_slug -eq 1 ]] || die "unknown resource slug for --only: $only_slug"
fi
if [[ -n "$provided_env_file" ]]; then
  [[ -n "$only_slug" ]] || die "--env-file requires --only"
  [[ -f "$provided_env_file" && ! -L "$provided_env_file" ]] || die "--env-file must be a regular, non-symlink file"
  provided_env_mode=$(stat -f '%Lp' "$provided_env_file" 2>/dev/null || stat -c '%a' "$provided_env_file")
  [[ "$provided_env_mode" == 600 ]] || die "--env-file must have mode 0600"
  grep -qx "PLATFORM_SLUG=$only_slug" "$provided_env_file" || die "--env-file does not belong to $only_slug"
fi
if [[ "$mode" == apply && ( -z "$only_slug" || "$only_slug" == qm ) && -z "$provided_env_file" ]]; then
  [[ -n "$qm_claude_token_file" ]] || die "QM generation requires --qm-claude-token-file"
  [[ -n "$qm_resend_key_file" ]] || die "QM generation requires --qm-resend-key-file"
fi

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM
  if [[ $api_managed -eq 1 ]]; then
    # Always close the temporary API window, even when provisioning fails.
    # The expanded values are fixed local configuration, not remote output.
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify sh -lc 'api_token=\$(cat $token_file 2>/dev/null || true); if [ -n \"\$api_token\" ]; then curl -sS -o /dev/null -H \"Authorization: Bearer \$api_token\" http://127.0.0.1:8080/api/v1/disable || true; fi'" >/dev/null 2>&1 || true
    # If no token was created, still close the API through Coolify's application model.
    if [[ $token_created -eq 0 ]]; then
      ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
        "docker exec coolify php artisan tinker --execute='\$settings=App\\Models\\InstanceSettings::get(); \$settings->is_api_enabled=false; \$settings->save();'" >/dev/null 2>&1 || true
    fi
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify php artisan tinker --execute='\$user=App\\Models\\User::findOrFail(0); \$user->tokens()->whereIn(\"name\",[\"$token_name\",\"$legacy_token_name\"])->delete();'" >/dev/null 2>&1 || true
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify rm -f $token_file $legacy_token_file" >/dev/null 2>&1 || true
  fi
  if [[ -n "$work_dir" && -d "$work_dir" ]]; then
    rm -rf -- "$work_dir"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

for command_name in jq openssl; do
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required"
done

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ogg-coolify-stack.XXXXXX")
chmod 700 "$work_dir"

qm_validation_token_file="$work_dir/qm-validation-claude-token"
qm_validation_resend_file="$work_dir/qm-validation-resend-key"
printf '%s' 'validation-only-claude-token-00000000000000000000000000000000' > "$qm_validation_token_file"
printf '%s' 'validation-only-resend-key-000000000000000000000000000000000' > "$qm_validation_resend_file"
chmod 600 "$qm_validation_token_file" "$qm_validation_resend_file"
[[ -n "$qm_claude_token_file" ]] || qm_claude_token_file=$qm_validation_token_file
[[ -n "$qm_resend_key_file" ]] || qm_resend_key_file=$qm_validation_resend_file

echo "Generating fresh environment values..."
infrastructure/generate-env.sh --output-dir "$work_dir"
for slug in "${platforms[@]}"; do
  generator_args=(
    --shared-env "$work_dir/platforms/$slug.shared.env"
    --output "$work_dir/$slug.env"
  )
  if [[ "$slug" == buzz ]]; then
    generator_args+=(--owner-pubkey "$buzz_owner_pubkey")
  fi
  if [[ "$slug" == social-reply ]]; then
    generator_args+=(--operator-email "$operator_email")
  fi
  if [[ "$slug" == qm ]]; then
    generator_args+=(--admin-email "$operator_email" --claude-token-file "$qm_claude_token_file" --resend-key-file "$qm_resend_key_file")
  fi
  "platforms/$slug/generate-env.sh" "${generator_args[@]}"
done
sed -i.bak "s/^OPERATOR_EMAIL_ALLOWLIST=.*/OPERATOR_EMAIL_ALLOWLIST=$operator_email/" "$work_dir/nudgra-oss.env"
rm -f -- "$work_dir/nudgra-oss.env.bak"

[[ $(find "$work_dir" -maxdepth 1 -type f -name '*.env' | wc -l | tr -d ' ') == 21 ]] || die "expected 21 generated env files"
for env_file in "$work_dir"/*.env; do
  [[ $(stat -f '%Lp' "$env_file") == 600 ]] || die "$env_file is not mode 0600"
  ! grep -Eq '=required$|=.+ is required$|=replace-with-|example\.invalid' "$env_file" || die "$env_file still contains a placeholder"
done

if [[ "$mode" == check ]]; then
  echo "CHECK PASSED: 20 environment files generated with no required placeholders; no remote changes made."
  exit 0
fi

[[ $reset -eq 1 || -n "$only_slug" ]] || die "--apply requires --reset unless --only selects one resource"
[[ -n "$ssh_key" && -f "$ssh_key" ]] || die "--ssh-key must name an existing private key"
git_auth_token=${GIT_AUTH_TOKEN:-}
if [[ -z "$git_auth_token" ]] && command -v gh >/dev/null 2>&1; then
  git_auth_token=$(gh auth token 2>/dev/null || true)
fi
[[ -n "$git_auth_token" ]] || die "set GIT_AUTH_TOKEN or authenticate GitHub CLI to load private repositories"

ssh_options=(-o BatchMode=yes -o ConnectTimeout=10 -o IdentitiesOnly=yes -i "$ssh_key")
ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" true

api_state=$(ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
  "docker exec coolify php artisan tinker --execute='print(json_encode([\"enabled\"=>App\\Models\\InstanceSettings::get()->is_api_enabled,\"allowed\"=>App\\Models\\InstanceSettings::get()->allowed_ips]));'")
[[ $(jq -r '.allowed' <<<"$api_state") == '127.0.0.1,::1' ]] || die "Coolify Allowed IPs must be exactly 127.0.0.1,::1"
if [[ $(jq -r '.enabled' <<<"$api_state") != true ]]; then
  ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
    "docker exec coolify php artisan tinker --execute='\$settings=App\\Models\\InstanceSettings::get(); \$settings->is_api_enabled=true; \$settings->save();'" >/dev/null
  echo "Enabled the localhost-only Coolify API for this run"
fi
api_managed=1

# The expanded values are fixed local configuration, not remote output.
# shellcheck disable=SC2029
ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
  "docker exec coolify php artisan tinker --execute='session([\"currentTeam\"=>App\\Models\\Team::findOrFail(0)]); \$user=App\\Models\\User::findOrFail(0); \$user->tokens()->whereIn(\"name\",[\"$token_name\",\"$legacy_token_name\"])->delete(); \$token=\$user->createToken(\"$token_name\",[\"root\"],now()->addHours(2)); file_put_contents(\"$token_file\",\$token->plainTextToken);'" >/dev/null
token_created=1

shared_network_name=$(awk -F= '$1 == "SHARED_NETWORK_NAME" {print substr($0, index($0, "=") + 1)}' "$work_dir/infrastructure.env")
[[ "$shared_network_name" =~ ^[A-Za-z0-9_.-]+$ ]] || die "invalid SHARED_NETWORK_NAME"
# The network name is locally validated before remote expansion.
# shellcheck disable=SC2029
if ! ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" "docker network inspect $shared_network_name" >/dev/null 2>&1; then
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" "docker network create --attachable $shared_network_name" >/dev/null
  echo "Created external Docker network $shared_network_name"
fi

api() {
  local method=$1 endpoint=$2
  [[ "$endpoint" =~ ^[A-Za-z0-9_./?=-]+$ ]] || die "unsafe API endpoint: $endpoint"
  if [[ "$method" == GET || "$method" == DELETE ]]; then
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify sh -lc 'api_token=\$(cat $token_file); curl --fail-with-body -sS -X $method -H \"Authorization: Bearer \$api_token\" \"http://127.0.0.1:8080/api/v1/$endpoint\"'"
  else
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec -i coolify sh -lc 'api_token=\$(cat $token_file); curl --fail-with-body -sS -X $method -H \"Authorization: Bearer \$api_token\" -H \"Content-Type: application/json\" --data-binary @- \"http://127.0.0.1:8080/api/v1/$endpoint\"'"
  fi
}

delete_application_envs() {
  local application_uuid=$1
  [[ "$application_uuid" =~ ^[A-Za-z0-9]+$ ]] || die "unsafe application UUID"
  # Delete through Coolify's API in one SSH session. The parser can emit the
  # same key more than once, so replacing rows individually is not sufficient.
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
    "docker exec -i coolify sh -lc 'api_token=\$(cat $token_file); while IFS= read -r env_uuid; do [ -n \"\$env_uuid\" ] || continue; case \"\$env_uuid\" in *[!A-Za-z0-9]*) exit 2;; esac; curl --fail-with-body -sS -o /dev/null -X DELETE -H \"Authorization: Bearer \$api_token\" \"http://127.0.0.1:8080/api/v1/applications/$application_uuid/envs/\$env_uuid\"; done'"
}

projects_json=$(api GET projects </dev/null) || die "could not list Coolify projects"
for stack in "${stacks[@]}"; do
  IFS='|' read -r slug project_name _ _ _ _ <<<"$stack"
  [[ -z "$only_slug" || "$slug" == "$only_slug" ]] || continue
  while IFS= read -r project_uuid; do
    [[ -n "$project_uuid" ]] || continue
    [[ $reset -eq 1 ]] || die "$project_name already exists; pass --reset to replace that exact target"
    project_json=$(api GET "projects/$project_uuid" </dev/null) || die "could not inspect $project_name"
    while IFS= read -r environment_uuid; do
      [[ -n "$environment_uuid" ]] || continue
      environment_json=$(api GET "projects/$project_uuid/$environment_uuid" </dev/null) || die "could not inspect $project_name environment"
      while IFS= read -r application_uuid; do
        [[ -n "$application_uuid" ]] || continue
        api DELETE "applications/$application_uuid" </dev/null >/dev/null || die "could not delete application $application_uuid"
      done < <(jq -r '.applications[]?.uuid // empty' <<<"$environment_json")
      while IFS= read -r service_uuid; do
        [[ -n "$service_uuid" ]] || continue
        api DELETE "services/$service_uuid" </dev/null >/dev/null || die "could not delete service $service_uuid"
      done < <(jq -r '.services[]?.uuid // empty' <<<"$environment_json")
    done < <(jq -r '.environments[]?.uuid // empty' <<<"$project_json")

    deleted=0
    for _ in {1..30}; do
      if api DELETE "projects/$project_uuid" </dev/null >/dev/null 2>&1; then
        deleted=1
        break
      fi
      sleep 2
    done
    [[ $deleted -eq 1 ]] || die "could not delete project $project_name"
    echo "Deleted $project_name"
  done < <(jq -r --arg name "$project_name" '.[] | select(.name == $name) | .uuid' <<<"$projects_json")
done

manifest=$work_dir/resources.tsv
: > "$manifest"
for stack in "${stacks[@]}"; do
  IFS='|' read -r slug project_name compose_location resource_name domains_json description <<<"$stack"
  [[ -z "$only_slug" || "$slug" == "$only_slug" ]] || continue
  project_payload=$(jq -n --arg name "$project_name" --arg description "$description" '{name:$name,description:$description}')
  project_response=$(printf '%s' "$project_payload" | api POST projects) || die "could not create project $project_name"
  project_uuid=$(jq -er .uuid <<<"$project_response") || die "Coolify returned no project UUID for $project_name"

  # Coolify 4.1.2 validates docker_compose_domains during creation but stores the
  # array incorrectly. Create first, wait for Compose parsing, then PATCH domains.
  application_payload=$(jq -n \
    --arg project_uuid "$project_uuid" \
    --arg server_uuid "$server_uuid" \
    --arg repository_url "$repository_url" \
    --arg compose_location "$compose_location" \
    --arg resource_name "$resource_name" \
    --arg description "$description" \
    '{project_uuid:$project_uuid,server_uuid:$server_uuid,environment_name:"production",git_repository:$repository_url,git_branch:"main",build_pack:"dockercompose",docker_compose_location:$compose_location,name:$resource_name,description:$description,autogenerate_domain:false,instant_deploy:false,is_auto_deploy_enabled:false,is_force_https_enabled:true,connect_to_docker_network:false,is_container_label_escape_enabled:false}')
  application_response=$(printf '%s' "$application_payload" | api POST applications/public) || die "could not create application $resource_name"
  application_uuid=$(jq -er .uuid <<<"$application_response") || die "Coolify returned no application UUID for $resource_name"
  [[ "$application_uuid" =~ ^[A-Za-z0-9]+$ ]] || die "Coolify returned an unsafe application UUID for $resource_name"

  if [[ "$slug" == social-reply || "$slug" == qm ]]; then
    # Coolify 4.1.2's optional build-arg injector does not understand
    # dockerfile_inline with remote Git contexts. These recipes pass build args
    # explicitly and supply Git authentication as a BuildKit secret.
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify php artisan tinker --execute='\$application=App\\Models\\Application::where(\"uuid\",\"$application_uuid\")->firstOrFail(); \$application->settings->inject_build_args_to_dockerfile=false; \$application->settings->save();'" >/dev/null
  fi
  printf '%s\t%s\t%s\t%s\n' "$slug" "$project_uuid" "$application_uuid" "$domains_json" >> "$manifest"

  # Coolify saves docker_compose_raw before it finishes extracting environment
  # rows. Wait until the extracted key set is stable before replacing values.
  parsed=0
  stable_count=0
  previous_env_signature=""
  for _ in {1..60}; do
    application_json=$(api GET "applications/$application_uuid" </dev/null) || die "could not inspect $slug"
    envs_json=$(api GET "applications/$application_uuid/envs" </dev/null) || die "could not inspect $slug environment"
    env_signature=$(jq -r '[.[].key] | sort | join(",")' <<<"$envs_json")
    if [[ $(jq -r '(.docker_compose_raw // "") | length > 0' <<<"$application_json") == true && -n "$env_signature" ]]; then
      if [[ "$env_signature" == "$previous_env_signature" ]]; then
        stable_count=$((stable_count + 1))
      else
        stable_count=0
      fi
      previous_env_signature=$env_signature
    fi
    if [[ $stable_count -ge 2 ]]; then
      parsed=1
      break
    fi
    sleep 2
  done
  [[ $parsed -eq 1 ]] || die "Coolify did not finish parsing $slug Compose environment"

  if [[ "$domains_json" != '[]' ]]; then
    domain_payload=$(jq -n --argjson domains "$domains_json" '{docker_compose_domains:$domains}')
    if ! printf '%s' "$domain_payload" | api PATCH "applications/$application_uuid" >/dev/null; then
      die "could not set domains for $slug"
    fi
  fi

  # Discard parser-generated defaults/placeholders, including duplicate rows,
  # then create one authoritative generated row per key.
  envs_json=$(api GET "applications/$application_uuid/envs" </dev/null) || die "could not inspect $slug environment"
  if ! jq -r '.[].uuid' <<<"$envs_json" | delete_application_envs "$application_uuid"; then
    die "could not clear parser-generated environment for $slug"
  fi

  env_file=$work_dir/infrastructure.env
  [[ "$slug" == infrastructure ]] || env_file=$work_dir/$slug.env
  [[ -z "$provided_env_file" ]] || env_file=$provided_env_file
  env_payload=$(jq -Rn \
    --rawfile git_auth_token <(printf '%s' "$git_auth_token") \
    '{data:[inputs | select(length > 0 and (startswith("#") | not)) | capture("^(?<key>[^=]+)=(?<value>.*)$") | if .key == "GIT_AUTH_TOKEN" and .value == "" then .value = $git_auth_token else . end | {key:.key,value:.value,is_preview:false,is_literal:false,is_multiline:false,is_shown_once:(.key | test("PASSWORD|SECRET|ACCESS_KEY|API_KEY|AUTH_TOKEN|APP_KEY|SIGNING_KEY")),is_runtime:true,is_buildtime:true,comment:"Generated by coolify-stack"}]}' "$env_file")
  if ! printf '%s' "$env_payload" | api PATCH "applications/$application_uuid/envs/bulk" >/dev/null; then
    die "could not load env for $slug"
  fi
  unset env_payload

  uploaded_envs_json=$(api GET "applications/$application_uuid/envs" </dev/null) || die "could not verify $slug environment"
  # Coolify mirrors each production row into preview scope. A duplicate means
  # the same key appears more than once inside the same scope.
  duplicate_count=$(jq '[group_by([.is_preview, .key])[] | select(length > 1)] | length' <<<"$uploaded_envs_json")
  placeholder_count=$(jq '[.[] | select((.value // "") == "required" or ((.value // "") | endswith(" is required")))] | length' <<<"$uploaded_envs_json")
  expected_signature=$(awk -F= '/^[[:space:]]*#/ || /^[[:space:]]*$/ {next} {print $1}' "$env_file" | sort | paste -sd, -)
  actual_signature=$(jq -r '[.[] | select(.is_preview == false and (.key | startswith("SERVICE_") | not)) | .key] | sort | join(",")' <<<"$uploaded_envs_json")
  [[ "$duplicate_count" == 0 ]] || die "$slug environment contains duplicate keys after upload"
  [[ "$placeholder_count" == 0 ]] || die "$slug environment still contains required placeholders after upload"
  [[ "$actual_signature" == "$expected_signature" ]] || die "$slug environment keys do not exactly match its generated env file"
  echo "Created and configured $project_name"
done

bad_status=0
while IFS=$'\t' read -r slug _ application_uuid _; do
  application_json=$(api GET "applications/$application_uuid" </dev/null) || die "could not verify $slug"
  status=$(jq -r '.status // "unknown"' <<<"$application_json")
  if [[ "$status" == running* ]]; then
    echo "ERROR: $slug is unexpectedly running" >&2
    bad_status=1
  fi
done < "$manifest"
[[ $bad_status -eq 0 ]] || die "one or more resources were deployed unexpectedly"

if [[ -n "$only_slug" ]]; then
  echo "DONE: $only_slug project and configured Git Compose resource created without touching any other project; nothing was deployed."
else
  echo "DONE: 20 projects and 20 configured Git Compose resources created; nothing was deployed."
fi
