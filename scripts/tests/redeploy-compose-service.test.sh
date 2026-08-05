#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
test_dir=$(mktemp -d)
cleanup() { rm -rf "$test_dir"; }
trap cleanup EXIT

application_uuid=testapplication
service_name=nginx
configuration_dir="$test_dir/applications/$application_uuid"
source_dir="$test_dir/source"
fake_docker="$test_dir/docker"
state_file="$test_dir/state"
log_file="$test_dir/docker.log"
mkdir -p "$configuration_dir" "$source_dir"
touch "$configuration_dir/docker-compose.yaml" "$configuration_dir/.env"
touch "$source_dir/compose.yaml"
printf 'before\n' > "$state_file"

cat > "$fake_docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${COOLIFY_RESOURCE_UUID:-} == testapplication ]] || exit 65
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG_FILE"

case "$1" in
  compose)
    if [[ " $* " == *' config --services '* ]]; then
      printf 'web\nnginx\n'
      exit 0
    fi
    [[ " $* " == *' up -d --no-deps --force-recreate --no-build nginx '* ]] || exit 64
    printf 'after\n' > "$FAKE_DOCKER_STATE_FILE"
    ;;
  ps)
    printf 'web-old|web-test|web\n'
    if grep -qx before "$FAKE_DOCKER_STATE_FILE"; then
      printf 'nginx-old|nginx-test|nginx\n'
    else
      printf 'nginx-new|nginx-test|nginx\n'
    fi
    ;;
  inspect)
    printf 'running|healthy\n'
    ;;
  *) exit 64 ;;
esac
EOF
chmod 755 "$fake_docker"

COOLIFY_APPLICATIONS_DIR="$test_dir/applications" \
COOLIFY_SERVICE_PROJECT_DIR="$source_dir" \
DOCKER_BIN="$fake_docker" \
FAKE_DOCKER_STATE_FILE="$state_file" \
FAKE_DOCKER_LOG_FILE="$log_file" \
  "$repo_root/scripts/server/redeploy-compose-service" \
    "$application_uuid" "$service_name" 60 0 >/dev/null

grep -Fq 'up -d --no-deps --force-recreate --no-build nginx' "$log_file"
grep -Fq -- "--project-directory $source_dir -f $configuration_dir/docker-compose.yaml -f $source_dir/compose.yaml config --services" "$log_file"
[[ -L "$source_dir/.env" ]]
[[ $(readlink "$source_dir/.env") == "$configuration_dir/.env" ]]
grep -qx after "$state_file"

echo "Compose service redeployment tests passed."
