#!/usr/bin/env bash
set -euo pipefail

umask 077

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

coolify_host=${COOLIFY_HOST:-68.183.135.86}
coolify_user=${COOLIFY_USER:-root}
ssh_key=${COOLIFY_SSH_KEY:-}
mode=""
app_slug=""
env_file=""
copy_live_specs=()
deploy_after_update=0
allow_empty=0
token_name=ogg-coolify-stack-env-update
token_file=/tmp/ogg-coolify-stack-env-update-token
api_managed=0
token_created=0
ssh_control_dir=""

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/update-app-env.sh --check --app SLUG --env-file PATH
  scripts/update-app-env.sh --apply --app SLUG --env-file PATH --ssh-key PATH [--deploy]
  scripts/update-app-env.sh --apply --app SLUG --copy-live TARGET=SOURCE [--copy-live TARGET=SOURCE ...] --ssh-key PATH [--deploy]

Adds or updates only the keys listed in a mode-0600 env file. Existing keys not
listed in that file are preserved. Alternatively, --copy-live copies an existing
production variable to another key in the same app without exposing its value.
Values are never printed.

Options:
  --check           Validate the input file and app slug without contacting Coolify.
  --apply           Upsert the listed production environment variables in Coolify.
  --app SLUG        Target one existing stack, for example postiz or kensi-ai.
  --env-file PATH   File containing KEY=value lines. Blank lines and comments are allowed.
  --copy-live T=S   Copy production key SOURCE to TARGET in the same app. Repeatable;
                    supported only with --apply and mutually exclusive with --env-file.
  --ssh-key PATH    SSH private key used for the Coolify host.
  --host HOST       Coolify server SSH host (default: 68.183.135.86).
  --allow-empty     Permit KEY= entries that intentionally clear a value.
  --deploy          After a successful update, deploy only the selected stack.

Before --apply, Coolify API Allowed IPs must be exactly:
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
    --app) [[ $# -ge 2 ]] || die "--app needs a slug"; app_slug=$2; shift 2 ;;
    --env-file) [[ $# -ge 2 ]] || die "--env-file needs a path"; env_file=$2; shift 2 ;;
    --copy-live) [[ $# -ge 2 ]] || die "--copy-live needs TARGET=SOURCE"; copy_live_specs+=("$2"); shift 2 ;;
    --ssh-key) [[ $# -ge 2 ]] || die "--ssh-key needs a path"; ssh_key=$2; shift 2 ;;
    --host) [[ $# -ge 2 ]] || die "--host needs a value"; coolify_host=$2; shift 2 ;;
    --allow-empty) allow_empty=1; shift ;;
    --deploy) deploy_after_update=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "$mode" ]] || { usage; exit 2; }
[[ -n "$app_slug" ]] || die "--app is required"
[[ -n "$env_file" || ${#copy_live_specs[@]} -gt 0 ]] || die "--env-file or --copy-live is required"
[[ -z "$env_file" || ${#copy_live_specs[@]} -eq 0 ]] || die "--env-file and --copy-live are mutually exclusive"
[[ $deploy_after_update -eq 0 || "$mode" == apply ]] || die "--deploy requires --apply"

# slug|Coolify application name
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
  'qm|QM Stack'
)

resource_name=""
for resource_spec in "${resource_specs[@]}"; do
  IFS='|' read -r slug candidate_name <<<"$resource_spec"
  if [[ "$slug" == "$app_slug" ]]; then
    resource_name=$candidate_name
    break
  fi
done
[[ -n "$resource_name" ]] || die "unknown app slug: $app_slug"

env_payload=""
copy_specs_json='[]'

if [[ -n "$env_file" ]]; then
  [[ -f "$env_file" && ! -L "$env_file" ]] || die "--env-file must be a regular, non-symlink file"
  env_file_mode=$(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file")
  [[ "$env_file_mode" == 600 ]] || die "--env-file must have mode 0600 (run: chmod 600 '$env_file')"

  invalid_lines=$(awk '
    {
      line = $0
      sub(/\r$/, "", line)
    }
    line ~ /^[[:space:]]*($|#)/ { next }
    line !~ /^[A-Za-z_][A-Za-z0-9_]*=/ { print NR }
  ' "$env_file" | paste -sd, -)
  [[ -z "$invalid_lines" ]] || die "invalid KEY=value syntax on line(s): $invalid_lines"

  keys=$(awk '
    {
      line = $0
      sub(/\r$/, "", line)
    }
    line ~ /^[[:space:]]*($|#)/ { next }
    {
      key = line
      sub(/=.*/, "", key)
      print key
    }
  ' "$env_file")
  [[ -n "$keys" ]] || die "--env-file contains no environment variables"

  duplicate_keys=$(printf '%s\n' "$keys" | sort | uniq -d | paste -sd, -)
  [[ -z "$duplicate_keys" ]] || die "duplicate key(s) in --env-file: $duplicate_keys"

  if [[ $allow_empty -eq 0 ]]; then
    empty_keys=$(awk '
      {
        line = $0
        sub(/\r$/, "", line)
      }
      line ~ /^[[:space:]]*($|#)/ { next }
      {
        key = line
        sub(/=.*/, "", key)
        value = substr(line, index(line, "=") + 1)
        if (length(value) == 0) {
          print key
        }
      }
    ' "$env_file" | paste -sd, -)
    [[ -z "$empty_keys" ]] || die "empty value(s) require --allow-empty: $empty_keys"
  fi

  command -v jq >/dev/null 2>&1 || die "jq is required"

  env_payload=$(jq -Rn '
    {
      data: [
        inputs
        | sub("\r$"; "")
        | select(test("^[[:space:]]*(#|$)") | not)
        | capture("^(?<key>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$")
        | {
            key: .key,
            value: .value,
            is_preview: false,
            is_literal: false,
            is_multiline: false,
            is_shown_once: (.key | test("PASSWORD|SECRET|PRIVATE_KEY|ACCESS_KEY|API_KEY|AUTH_TOKEN|CLIENT_SECRET|SIGNING_KEY|WEBHOOK_SECRET"; "i")),
            is_runtime: true,
            is_buildtime: true,
            comment: "Managed by update-app-env.sh"
          }
      ]
    }
  ' "$env_file")
  key_count=$(jq '.data | length' <<<"$env_payload")
  target_keys_json=$(jq '[.data[].key]' <<<"$env_payload")
  key_list=$(jq -r '.data[].key' <<<"$env_payload" | paste -sd, -)

  if [[ "$mode" == check ]]; then
    echo "CHECK PASSED: $key_count key(s) for $app_slug ($key_list); no remote changes made."
    exit 0
  fi
else
  [[ "$mode" == apply ]] || die "--copy-live is supported only with --apply"
  [[ $allow_empty -eq 0 ]] || die "--allow-empty is not supported with --copy-live"
  command -v jq >/dev/null 2>&1 || die "jq is required"

  for copy_spec in "${copy_live_specs[@]}"; do
    [[ "$copy_spec" =~ ^[A-Za-z_][A-Za-z0-9_]*=[A-Za-z_][A-Za-z0-9_]*$ ]] || \
      die "invalid --copy-live mapping: $copy_spec (expected TARGET=SOURCE)"
  done
  copy_specs_json=$(printf '%s\n' "${copy_live_specs[@]}" | jq -Rn '
    [inputs | capture("^(?<target>[A-Za-z_][A-Za-z0-9_]*)=(?<source>[A-Za-z_][A-Za-z0-9_]*)$")]
  ')
  duplicate_targets=$(jq -r '[.[].target] | group_by(.) | map(select(length > 1) | .[0]) | join(",")' <<<"$copy_specs_json")
  [[ -z "$duplicate_targets" ]] || die "duplicate --copy-live target key(s): $duplicate_targets"
  key_count=$(jq 'length' <<<"$copy_specs_json")
  target_keys_json=$(jq '[.[].target]' <<<"$copy_specs_json")
  key_list=$(jq -r '.[].target' <<<"$copy_specs_json" | paste -sd, -)
fi

[[ -n "$ssh_key" && -f "$ssh_key" ]] || die "--ssh-key must name an existing private key"

ssh_control_dir=$(mktemp -d /tmp/ogg-coolify-stack-env-ssh.XXXXXX)
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

close_api() {
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
    api_managed=0
    token_created=0
  fi
}

close_control() {
  if [[ -n "$ssh_control_dir" ]]; then
    ssh "${ssh_options[@]}" -O exit "$coolify_user@$coolify_host" >/dev/null 2>&1 || true
    rmdir "$ssh_control_dir" >/dev/null 2>&1 || true
    ssh_control_dir=""
  fi
}

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM
  close_api
  close_control
  unset env_payload existing_envs_json updated_envs_json
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
  "docker exec coolify php artisan tinker --execute='session([\"currentTeam\"=>App\\Models\\Team::findOrFail(0)]); \$user=App\\Models\\User::findOrFail(0); \$user->tokens()->where(\"name\",\"$token_name\")->delete(); \$token=\$user->createToken(\"$token_name\",[\"root\"],now()->addMinutes(30)); file_put_contents(\"$token_file\",\$token->plainTextToken);'" >/dev/null
token_created=1

api() {
  local method=$1 endpoint=$2
  [[ "$endpoint" =~ ^[A-Za-z0-9_./?=\&-]+$ ]] || die "unsafe API endpoint: $endpoint"
  if [[ "$method" == GET || "$method" == DELETE ]]; then
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec coolify sh -lc 'api_token=\$(cat $token_file); curl --fail-with-body -sS -X $method -H \"Authorization: Bearer \$api_token\" \"http://127.0.0.1:8080/api/v1/$endpoint\"'"
  else
    # Payload is sent through stdin so secret values never appear in arguments.
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$coolify_user@$coolify_host" \
      "docker exec -i coolify sh -lc 'api_token=\$(cat $token_file); curl --fail-with-body -sS -X $method -H \"Authorization: Bearer \$api_token\" -H \"Content-Type: application/json\" --data-binary @- \"http://127.0.0.1:8080/api/v1/$endpoint\"'"
  fi
}

applications_json=$(api GET applications </dev/null) || die "could not list Coolify applications"
matches=$(jq --arg name "$resource_name" '[.[] | select(.name == $name)] | length' <<<"$applications_json")
[[ "$matches" == 1 ]] || die "expected exactly one existing application named $resource_name, found $matches"
application_uuid=$(jq -r --arg name "$resource_name" '.[] | select(.name == $name) | .uuid' <<<"$applications_json")
[[ "$application_uuid" =~ ^[A-Za-z0-9]+$ ]] || die "Coolify returned an unsafe application UUID"

existing_envs_json=$(api GET "applications/$application_uuid/envs" </dev/null) || die "could not inspect $app_slug environment"
duplicates_before=$(jq -r --argjson keys "$target_keys_json" '
  [
    .[]
    | select(.is_preview == false and (.key as $key | $keys | index($key)))
    | .key
  ]
  | group_by(.)
  | map(select(length > 1) | .[0])
  | join(",")
' <<<"$existing_envs_json")
[[ -z "$duplicates_before" ]] || die "$app_slug already contains duplicate production key(s): $duplicates_before"

if [[ ${#copy_live_specs[@]} -gt 0 ]]; then
  source_issues=$(jq -r --argjson specs "$copy_specs_json" '
    [
      $specs[] as $spec
      | ([.[] | select(.is_preview == false and .key == $spec.source)] | length) as $count
      | select($count != 1)
      | "\($spec.source)=\($count)"
    ]
    | unique
    | join(",")
  ' <<<"$existing_envs_json")
  [[ -z "$source_issues" ]] || die "--copy-live source key count must be exactly one: $source_issues"

  empty_sources=$(jq -r --argjson specs "$copy_specs_json" '
    [
      $specs[] as $spec
      | .[]
      | select(.is_preview == false and .key == $spec.source and ((.value // "") | length) == 0)
      | $spec.source
    ]
    | unique
    | join(",")
  ' <<<"$existing_envs_json")
  [[ -z "$empty_sources" ]] || die "--copy-live source key(s) are empty: $empty_sources"

  env_payload=$(jq --argjson specs "$copy_specs_json" '
    {
      data: [
        $specs[] as $spec
        | (.[] | select(.is_preview == false and .key == $spec.source)) as $source
        | {
            key: $spec.target,
            value: $source.value,
            is_preview: false,
            is_literal: false,
            is_multiline: ($source.is_multiline // false),
            is_shown_once: (($source.is_shown_once // false) or ($spec.target | test("PASSWORD|SECRET|PRIVATE_KEY|ACCESS_KEY|API_KEY|AUTH_TOKEN|CLIENT_SECRET|SIGNING_KEY|WEBHOOK_SECRET"; "i"))),
            is_runtime: true,
            is_buildtime: true,
            comment: ("Copied from " + $spec.source + " by update-app-env.sh")
          }
      ]
    }
  ' <<<"$existing_envs_json")
fi

printf '%s' "$env_payload" | api PATCH "applications/$application_uuid/envs/bulk" >/dev/null || die "could not update $app_slug environment"
unset env_payload

updated_envs_json=$(api GET "applications/$application_uuid/envs" </dev/null) || die "could not verify $app_slug environment"
duplicates_after=$(jq -r --argjson keys "$target_keys_json" '
  [
    .[]
    | select(.is_preview == false and (.key as $key | $keys | index($key)))
    | .key
  ]
  | group_by(.)
  | map(select(length > 1) | .[0])
  | join(",")
' <<<"$updated_envs_json")
missing_after=$(jq -r --argjson keys "$target_keys_json" '
  [
    .[]
    | select(.is_preview == false and (.key as $key | $keys | index($key)))
    | .key
  ] as $present
  | ($keys - $present)
  | unique
  | join(",")
' <<<"$updated_envs_json")
[[ -z "$duplicates_after" ]] || die "$app_slug contains duplicate production key(s) after update: $duplicates_after"
[[ -z "$missing_after" ]] || die "$app_slug is missing production key(s) after update: $missing_after"

if [[ ${#copy_live_specs[@]} -gt 0 ]]; then
  copy_mismatches=$(jq -r --argjson specs "$copy_specs_json" '
    [
      $specs[] as $spec
      | ([.[] | select(.is_preview == false and .key == $spec.source)][0].value) as $source_value
      | ([.[] | select(.is_preview == false and .key == $spec.target)][0].value) as $target_value
      | select($source_value != $target_value)
      | $spec.target
    ]
    | unique
    | join(",")
  ' <<<"$updated_envs_json")
  [[ -z "$copy_mismatches" ]] || die "$app_slug copied value verification failed for key(s): $copy_mismatches"
fi

echo "UPDATED: $app_slug now has exactly one production row for $key_count key(s): $key_list"

if [[ $deploy_after_update -eq 1 ]]; then
  close_api
  close_control
  "$repo_root/scripts/deploy-resources.sh" \
    --apply \
    --only "$app_slug" \
    --host "$coolify_host" \
    --ssh-key "$ssh_key"
else
  echo "Configuration is saved but not deployed. Apply it with:"
  printf 'scripts/deploy-resources.sh --apply --only %q --host %q --ssh-key %q\n' \
    "$app_slug" "$coolify_host" "$ssh_key"
fi
