#!/usr/bin/env bash
set -euo pipefail

coolify_host=${COOLIFY_HOST:-68.183.135.86}
coolify_user=${COOLIFY_USER:-root}
ssh_key=${COOLIFY_SSH_KEY:-}
timeout_seconds=${DEPLOY_TIMEOUT_SECONDS:-5400}
only_slug=""
token_name=ogg-coolify-stack-deploy
token_file=/tmp/ogg-coolify-stack-deploy-token
api_managed=0
token_created=0
active_deployment_uuid=""

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/deploy-resources.sh --apply --ssh-key PATH
  scripts/deploy-resources.sh --apply --only SLUG --ssh-key PATH

Deploys the existing Coolify resources in dependency order. It does not create,
delete, or reconfigure resources, environments, domains, networks, or volumes.

Options:
  --apply           Deploy the existing resources.
  --ssh-key PATH    SSH private key used for the Coolify host.
  --host HOST       Coolify server SSH host (default: 68.183.135.86).
  --timeout SECONDS Per-resource deployment timeout (default: 5400).
  --only SLUG       Deploy only one resource (for example: infrastructure or kensi-ai).
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

mode=""
while (($#)); do
  case "$1" in
    --apply) mode=apply; shift ;;
    --ssh-key) [[ $# -ge 2 ]] || die "--ssh-key needs a path"; ssh_key=$2; shift 2 ;;
    --host) [[ $# -ge 2 ]] || die "--host needs a value"; coolify_host=$2; shift 2 ;;
    --timeout) [[ $# -ge 2 ]] || die "--timeout needs seconds"; timeout_seconds=$2; shift 2 ;;
    --only) [[ $# -ge 2 ]] || die "--only needs a slug"; only_slug=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ "$mode" == apply ]] || { usage; exit 2; }
[[ -n "$ssh_key" && -f "$ssh_key" ]] || die "--ssh-key must name an existing private key"
[[ "$timeout_seconds" =~ ^[0-9]+$ && "$timeout_seconds" -ge 60 ]] || die "--timeout must be at least 60 seconds"
command -v jq >/dev/null 2>&1 || die "jq is required"

resource_specs=(
  'infrastructure|Shared Infrastructure Stack'
  'kensi-ai|Kensi AI Stack'
  'agentshq|AgentsHQ Stack'
  'open-kudos|TeamToast Stack'
  'insight|Clavinci Stack'
  'togglebox|Togglebox Stack'
  'openpay|OpenPay Stack'
  'ploon|Ploon Stack'
  'open-growth-group|Open Growth Group Stack'
  'lokei|Lokei Stack'
  'albert|Albert Stack'
  'record-cloud|Record Cloud Stack'
  'plane|Plane Stack'
  'postiz|Postiz Stack'
  'nudgra-oss|Nudgra OSS Stack'
  'n8n|N8N Stack'
  'twenty|Twenty Stack'
  'buzz|Buzz Stack'
  'social-reply|SocialReply Stack'
)

if [[ -n "$only_slug" ]]; then
  known_slug=0
  for resource_spec in "${resource_specs[@]}"; do
    IFS='|' read -r slug _ <<<"$resource_spec"
    [[ "$slug" == "$only_slug" ]] && known_slug=1
  done
  [[ $known_slug -eq 1 ]] || die "unknown resource slug for --only: $only_slug"
fi

ssh_control_dir=$(mktemp -d /tmp/ogg-coolify-stack-ssh.XXXXXX)
ssh_control_path="$ssh_control_dir/control"
ssh_options=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o IdentitiesOnly=yes
  -o ControlMaster=auto
  -o ControlPersist=60
  -o ControlPath="$ssh_control_path"
  -i "$ssh_key"
)

cleanup() {
  local exit_code=$?
  trap - EXIT
  trap '' INT TERM
  if [[ $api_managed -eq 1 ]]; then
    if [[ $exit_code -ne 0 && "$active_deployment_uuid" =~ ^[A-Za-z0-9]+$ ]]; then
      # Cancel only the deployment queued by this run. This prevents a local
      # interruption from leaving a remote Coolify deployment running.
      # shellcheck disable=SC2029
      ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
        "docker exec coolify sh -lc 'api_token=\$(cat $token_file 2>/dev/null || true); if [ -n \"\$api_token\" ]; then curl -sS -o /dev/null -X POST -H \"Authorization: Bearer \$api_token\" http://127.0.0.1:8080/api/v1/deployments/$active_deployment_uuid/cancel || true; fi'" >/dev/null 2>&1 || true
    fi
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify sh -lc 'api_token=\$(cat $token_file 2>/dev/null || true); if [ -n \"\$api_token\" ]; then curl -sS -o /dev/null -H \"Authorization: Bearer \$api_token\" http://127.0.0.1:8080/api/v1/disable || true; fi'" >/dev/null 2>&1 || true
    if [[ $token_created -eq 0 ]]; then
      ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
        "docker exec coolify php artisan tinker --execute='\$settings=App\\Models\\InstanceSettings::get(); \$settings->is_api_enabled=false; \$settings->save();'" >/dev/null 2>&1 || true
    fi
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify php artisan tinker --execute='\$user=App\\Models\\User::findOrFail(0); \$user->tokens()->where(\"name\",\"$token_name\")->delete();'" >/dev/null 2>&1 || true
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify rm -f $token_file" >/dev/null 2>&1 || true
  fi
  ssh "${ssh_options[@]}" -O exit "$coolify_user@$coolify_host" >/dev/null 2>&1 || true
  rmdir "$ssh_control_dir" >/dev/null 2>&1 || true
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" true

api_state=$(ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
  "docker exec coolify php artisan tinker --execute='print(json_encode([\"enabled\"=>App\\Models\\InstanceSettings::get()->is_api_enabled,\"allowed\"=>App\\Models\\InstanceSettings::get()->allowed_ips]));'")
[[ $(jq -r '.allowed' <<<"$api_state") == '127.0.0.1,::1' ]] || die "Coolify Allowed IPs must be exactly 127.0.0.1,::1"
if [[ $(jq -r '.enabled' <<<"$api_state") != true ]]; then
  ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
    "docker exec coolify php artisan tinker --execute='\$settings=App\\Models\\InstanceSettings::get(); \$settings->is_api_enabled=true; \$settings->save();'" >/dev/null
fi
api_managed=1

# shellcheck disable=SC2029
ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
  "docker exec coolify php artisan tinker --execute='session([\"currentTeam\"=>App\\Models\\Team::findOrFail(0)]); \$user=App\\Models\\User::findOrFail(0); \$user->tokens()->where(\"name\",\"$token_name\")->delete(); \$token=\$user->createToken(\"$token_name\",[\"root\"],now()->addHours(18)); file_put_contents(\"$token_file\",\$token->plainTextToken);'" >/dev/null
token_created=1

api() {
  local method=$1 endpoint=$2
  [[ "$endpoint" =~ ^[A-Za-z0-9_./?=\&-]+$ ]] || die "unsafe API endpoint: $endpoint"
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
    "docker exec coolify sh -lc 'api_token=\$(cat $token_file); curl --fail-with-body -sS -X $method -H \"Authorization: Bearer \$api_token\" \"http://127.0.0.1:8080/api/v1/$endpoint\"'"
}

applications_json=$(api GET applications) || die "could not list Coolify applications"

deployed_count=0
for resource_spec in "${resource_specs[@]}"; do
  IFS='|' read -r slug resource_name <<<"$resource_spec"
  [[ -z "$only_slug" || "$slug" == "$only_slug" ]] || continue
  matches=$(jq --arg name "$resource_name" '[.[] | select(.name == $name)] | length' <<<"$applications_json")
  [[ "$matches" == 1 ]] || die "expected exactly one existing application named $resource_name, found $matches"
  application_uuid=$(jq -r --arg name "$resource_name" '.[] | select(.name == $name) | .uuid' <<<"$applications_json")

  echo "Deploying $resource_name..."
  deployment_json=$(api POST "applications/$application_uuid/start?instant_deploy=true") || die "could not queue $resource_name"
  deployment_uuid=$(jq -er '.deployment_uuid' <<<"$deployment_json") || die "Coolify returned no deployment UUID for $resource_name"
  active_deployment_uuid=$deployment_uuid
  started_at=$SECONDS

  while true; do
    deployment_json=$(api GET "deployments/$deployment_uuid") || die "could not inspect deployment for $resource_name"
    status=$(jq -r '.status // "unknown"' <<<"$deployment_json")
    case "$status" in
      finished)
        application_json=$(api GET "applications/$application_uuid") || die "could not inspect $resource_name after deployment"
        echo "Deployed $resource_name ($(jq -r '.status // "unknown"' <<<"$application_json"))"
        active_deployment_uuid=""
        deployed_count=$((deployed_count + 1))
        break
        ;;
      failed|cancelled-by-user)
        active_deployment_uuid=""
        die "$resource_name deployment ended with status $status (deployment $deployment_uuid)"
        ;;
      queued|in_progress)
        ;;
      *)
        die "$resource_name deployment returned unexpected status $status"
        ;;
    esac
    (( SECONDS - started_at < timeout_seconds )) || die "$resource_name deployment timed out (deployment $deployment_uuid)"
    sleep 10
  done
done

if [[ -n "$only_slug" ]]; then
  echo "DONE: $only_slug deployed without touching any other resource."
else
  [[ $deployed_count -eq 19 ]] || die "expected to deploy 19 resources, deployed $deployed_count"
  echo "DONE: all 19 Coolify resources deployed in dependency order."
fi
