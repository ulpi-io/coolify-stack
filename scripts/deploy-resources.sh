#!/usr/bin/env bash
set -euo pipefail

coolify_host=${COOLIFY_HOST:-68.183.135.86}
coolify_user=${COOLIFY_USER:-root}
ssh_key=${COOLIFY_SSH_KEY:-}
timeout_seconds=${DEPLOY_TIMEOUT_SECONDS:-5400}
token_name=ogg-coolify-stack-deploy
token_file=/tmp/ogg-coolify-stack-deploy-token
api_managed=0
token_created=0

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/deploy-resources.sh --apply --ssh-key PATH

Deploys the existing Coolify resources in dependency order. It does not create,
delete, or reconfigure resources, environments, domains, networks, or volumes.

Options:
  --apply           Deploy the existing resources.
  --ssh-key PATH    SSH private key used for the Coolify host.
  --host HOST       Coolify server SSH host (default: 68.183.135.86).
  --timeout SECONDS Per-resource deployment timeout (default: 5400).
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
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ "$mode" == apply ]] || { usage; exit 2; }
[[ -n "$ssh_key" && -f "$ssh_key" ]] || die "--ssh-key must name an existing private key"
[[ "$timeout_seconds" =~ ^[0-9]+$ && "$timeout_seconds" -ge 60 ]] || die "--timeout must be at least 60 seconds"
command -v jq >/dev/null 2>&1 || die "jq is required"

resources=(
  'Shared Infrastructure Stack'
  'Kensi AI Stack'
  'AgentsHQ Stack'
  'TeamToast Stack'
  'Clavinci Stack'
  'Togglebox Stack'
  'OpenPay Stack'
  'Ploon Stack'
  'Open Growth Group Stack'
  'Lokei Stack'
  'Albert Stack'
  'Record Cloud Stack'
  'Plane Stack'
  'Postiz Stack'
  'Nudgra OSS Stack'
  'N8N Stack'
  'Twenty Stack'
)

ssh_options=(-o BatchMode=yes -o ConnectTimeout=10 -o IdentitiesOnly=yes -i "$ssh_key")

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM
  if [[ $api_managed -eq 1 ]]; then
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

for resource_name in "${resources[@]}"; do
  matches=$(jq --arg name "$resource_name" '[.[] | select(.name == $name)] | length' <<<"$applications_json")
  [[ "$matches" == 1 ]] || die "expected exactly one existing application named $resource_name, found $matches"
  application_uuid=$(jq -r --arg name "$resource_name" '.[] | select(.name == $name) | .uuid' <<<"$applications_json")

  echo "Deploying $resource_name..."
  deployment_json=$(api POST "applications/$application_uuid/start?force=true&instant_deploy=true") || die "could not queue $resource_name"
  deployment_uuid=$(jq -er '.deployment_uuid' <<<"$deployment_json") || die "Coolify returned no deployment UUID for $resource_name"
  started_at=$SECONDS

  while true; do
    deployment_json=$(api GET "deployments/$deployment_uuid") || die "could not inspect deployment for $resource_name"
    status=$(jq -r '.status // "unknown"' <<<"$deployment_json")
    case "$status" in
      finished)
        application_json=$(api GET "applications/$application_uuid") || die "could not inspect $resource_name after deployment"
        echo "Deployed $resource_name ($(jq -r '.status // "unknown"' <<<"$application_json"))"
        break
        ;;
      failed|cancelled-by-user)
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

echo "DONE: all 17 Coolify resources deployed in dependency order."
