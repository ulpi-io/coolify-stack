#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
  echo "Usage: $0 --output-dir DIR [--force]" >&2
}

output_dir=""
force=0
while (($#)); do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      output_dir=$2
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "$output_dir" ]] || { usage; exit 2; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }

infra_env="$output_dir/infrastructure.env"
fragments_dir="$output_dir/platforms"
platforms=(kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group lokei albert record-cloud plane postiz nudgra-oss n8n twenty)

if [[ $force -ne 1 ]]; then
  [[ ! -e "$infra_env" ]] || { echo "Refusing to overwrite $infra_env; pass --force" >&2; exit 1; }
  for slug in "${platforms[@]}"; do
    [[ ! -e "$fragments_dir/$slug.shared.env" ]] || { echo "Refusing to overwrite $fragments_dir/$slug.shared.env; pass --force" >&2; exit 1; }
  done
fi

mkdir -p "$fragments_dir"

random_hex() {
  openssl rand -hex 32
}

secret_vars=(
  MYSQL_ROOT_PASSWORD POSTGRES_ROOT_PASSWORD
  KENSI_AI_DB_PASSWORD AGENTSHQ_DB_PASSWORD OPEN_KUDOS_DB_PASSWORD INSIGHT_DB_PASSWORD
  TOGGLEBOX_DB_PASSWORD OPENPAY_DB_PASSWORD LOKEI_DB_PASSWORD ALBERT_DB_PASSWORD RECORD_CLOUD_DB_PASSWORD
  PLANE_DB_PASSWORD POSTIZ_DB_PASSWORD NUDGRA_DB_PASSWORD N8N_DB_PASSWORD TWENTY_DB_PASSWORD TEMPORAL_DB_PASSWORD
  VALKEY_ADMIN_PASSWORD PLANE_VALKEY_PASSWORD REDIS_CACHE_ADMIN_PASSWORD REDIS_QUEUE_ADMIN_PASSWORD
  LOKEI_CACHE_PASSWORD ALBERT_CACHE_PASSWORD KENSI_AI_CACHE_PASSWORD OPEN_KUDOS_CACHE_PASSWORD
  POSTIZ_CACHE_PASSWORD TWENTY_CACHE_PASSWORD OPENPAY_CACHE_PASSWORD
  LOKEI_QUEUE_PASSWORD ALBERT_QUEUE_PASSWORD KENSI_AI_QUEUE_PASSWORD OPEN_KUDOS_QUEUE_PASSWORD
  N8N_QUEUE_PASSWORD POSTIZ_QUEUE_PASSWORD OPENPAY_QUEUE_PASSWORD
  MINIO_ROOT_PASSWORD RECORD_CLOUD_S3_SECRET_KEY PLANE_S3_SECRET_KEY KENSI_AI_S3_SECRET_KEY OPENPAY_S3_SECRET_KEY TWENTY_S3_SECRET_KEY
  QDRANT_API_KEY PLANE_RABBITMQ_PASSWORD BACKUP_S3_ACCESS_KEY BACKUP_S3_SECRET_KEY
)
for var_name in "${secret_vars[@]}"; do
  printf -v "$var_name" '%s' "$(random_hex)"
done

MINIO_ROOT_USER=oggadmin
RECORD_CLOUD_S3_ACCESS_KEY=recordcloud
PLANE_S3_ACCESS_KEY=plane
KENSI_AI_S3_ACCESS_KEY=kensiai
OPENPAY_S3_ACCESS_KEY=openpay
TWENTY_S3_ACCESS_KEY=twenty

infra_tmp=$(mktemp "$output_dir/.infrastructure.env.XXXXXX")
cat > "$infra_tmp" <<EOF
SHARED_NETWORK_NAME=ogg-shared
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
POSTGRES_ROOT_PASSWORD=$POSTGRES_ROOT_PASSWORD
KENSI_AI_DB_PASSWORD=$KENSI_AI_DB_PASSWORD
AGENTSHQ_DB_PASSWORD=$AGENTSHQ_DB_PASSWORD
OPEN_KUDOS_DB_PASSWORD=$OPEN_KUDOS_DB_PASSWORD
INSIGHT_DB_PASSWORD=$INSIGHT_DB_PASSWORD
TOGGLEBOX_DB_PASSWORD=$TOGGLEBOX_DB_PASSWORD
OPENPAY_DB_PASSWORD=$OPENPAY_DB_PASSWORD
LOKEI_DB_PASSWORD=$LOKEI_DB_PASSWORD
ALBERT_DB_PASSWORD=$ALBERT_DB_PASSWORD
RECORD_CLOUD_DB_PASSWORD=$RECORD_CLOUD_DB_PASSWORD
PLANE_DB_PASSWORD=$PLANE_DB_PASSWORD
POSTIZ_DB_PASSWORD=$POSTIZ_DB_PASSWORD
NUDGRA_DB_PASSWORD=$NUDGRA_DB_PASSWORD
N8N_DB_PASSWORD=$N8N_DB_PASSWORD
TWENTY_DB_PASSWORD=$TWENTY_DB_PASSWORD
TEMPORAL_DB_PASSWORD=$TEMPORAL_DB_PASSWORD
VALKEY_ADMIN_PASSWORD=$VALKEY_ADMIN_PASSWORD
PLANE_VALKEY_PASSWORD=$PLANE_VALKEY_PASSWORD
REDIS_CACHE_ADMIN_PASSWORD=$REDIS_CACHE_ADMIN_PASSWORD
REDIS_QUEUE_ADMIN_PASSWORD=$REDIS_QUEUE_ADMIN_PASSWORD
LOKEI_CACHE_PASSWORD=$LOKEI_CACHE_PASSWORD
ALBERT_CACHE_PASSWORD=$ALBERT_CACHE_PASSWORD
KENSI_AI_CACHE_PASSWORD=$KENSI_AI_CACHE_PASSWORD
OPEN_KUDOS_CACHE_PASSWORD=$OPEN_KUDOS_CACHE_PASSWORD
POSTIZ_CACHE_PASSWORD=$POSTIZ_CACHE_PASSWORD
TWENTY_CACHE_PASSWORD=$TWENTY_CACHE_PASSWORD
OPENPAY_CACHE_PASSWORD=$OPENPAY_CACHE_PASSWORD
LOKEI_QUEUE_PASSWORD=$LOKEI_QUEUE_PASSWORD
ALBERT_QUEUE_PASSWORD=$ALBERT_QUEUE_PASSWORD
KENSI_AI_QUEUE_PASSWORD=$KENSI_AI_QUEUE_PASSWORD
OPEN_KUDOS_QUEUE_PASSWORD=$OPEN_KUDOS_QUEUE_PASSWORD
N8N_QUEUE_PASSWORD=$N8N_QUEUE_PASSWORD
POSTIZ_QUEUE_PASSWORD=$POSTIZ_QUEUE_PASSWORD
OPENPAY_QUEUE_PASSWORD=$OPENPAY_QUEUE_PASSWORD
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
RECORD_CLOUD_S3_ACCESS_KEY=$RECORD_CLOUD_S3_ACCESS_KEY
RECORD_CLOUD_S3_SECRET_KEY=$RECORD_CLOUD_S3_SECRET_KEY
PLANE_S3_ACCESS_KEY=$PLANE_S3_ACCESS_KEY
PLANE_S3_SECRET_KEY=$PLANE_S3_SECRET_KEY
KENSI_AI_S3_ACCESS_KEY=$KENSI_AI_S3_ACCESS_KEY
KENSI_AI_S3_SECRET_KEY=$KENSI_AI_S3_SECRET_KEY
OPENPAY_S3_ACCESS_KEY=$OPENPAY_S3_ACCESS_KEY
OPENPAY_S3_SECRET_KEY=$OPENPAY_S3_SECRET_KEY
TWENTY_S3_ACCESS_KEY=$TWENTY_S3_ACCESS_KEY
TWENTY_S3_SECRET_KEY=$TWENTY_S3_SECRET_KEY
QDRANT_API_KEY=$QDRANT_API_KEY
PLANE_RABBITMQ_PASSWORD=$PLANE_RABBITMQ_PASSWORD
TEMPORAL_CORS_ORIGINS=https://post.con.fyi
BACKUP_CRON_EXPRESSION=0 2 * * *
BACKUP_RETENTION_DAYS=14
BACKUP_S3_BUCKET=replace-with-offsite-bucket
BACKUP_S3_ACCESS_KEY=$BACKUP_S3_ACCESS_KEY
BACKUP_S3_SECRET_KEY=$BACKUP_S3_SECRET_KEY
BACKUP_S3_ENDPOINT=backup-storage.example.invalid
BACKUP_S3_ENDPOINT_PROTO=https
EOF
chmod 600 "$infra_tmp"
mv -f "$infra_tmp" "$infra_env"

write_fragment() {
  slug=$1
  shift
  target="$fragments_dir/$slug.shared.env"
  tmp=$(mktemp "$fragments_dir/.$slug.shared.env.XXXXXX")
  {
    echo "PLATFORM_SLUG=$slug"
    echo "SHARED_NETWORK_NAME=ogg-shared"
    printf '%s\n' "$@"
  } > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$target"
}

mysql_fragment() {
  slug=$1 db=$2 user=$3 password=$4
  shift 4
  write_fragment "$slug" \
    "DB_CONNECTION=mysql" "DB_HOST=mysql" "DB_PORT=3306" "DB_DATABASE=$db" "DB_USERNAME=$user" "DB_PASSWORD=$password" "$@"
}

postgres_fragment() {
  slug=$1 db=$2 user=$3 password=$4
  shift 4
  write_fragment "$slug" \
    "DB_CONNECTION=pgsql" "DB_HOST=postgresql" "DB_PORT=5432" "DB_DATABASE=$db" "DB_USERNAME=$user" "DB_PASSWORD=$password" "$@"
}

cache_lines() {
  printf '%s\n' "CACHE_HOST=redis-cache" "CACHE_PORT=6379" "CACHE_USERNAME=$1" "CACHE_PASSWORD=$2" "CACHE_PREFIX=$1:"
}

queue_lines() {
  printf '%s\n' "QUEUE_HOST=redis-queue" "QUEUE_PORT=6379" "QUEUE_USERNAME=$1" "QUEUE_PASSWORD=$2" "QUEUE_PREFIX=$1:"
}

valkey_lines() {
  printf '%s\n' "CACHE_HOST=valkey" "CACHE_PORT=6379" "CACHE_USERNAME=plane" "CACHE_PASSWORD=$PLANE_VALKEY_PASSWORD" "CACHE_PREFIX=plane:"
}

mail_lines=("SMTP_HOST=mailpit" "SMTP_PORT=1025" "SMTP_SECURE=false")

# Intentional splitting: each helper emits newline-separated KEY=value arguments.
# shellcheck disable=SC2046
mysql_fragment kensi-ai kensi_ai kensi_ai "$KENSI_AI_DB_PASSWORD" \
  $(cache_lines kensi-ai "$KENSI_AI_CACHE_PASSWORD") $(queue_lines kensi-ai "$KENSI_AI_QUEUE_PASSWORD") \
  "S3_ENDPOINT=http://minio:9000" "S3_REGION=us-east-1" "S3_BUCKET=kensi-ai" "S3_ACCESS_KEY=$KENSI_AI_S3_ACCESS_KEY" "S3_SECRET_KEY=$KENSI_AI_S3_SECRET_KEY" "S3_PATH_STYLE=true" "${mail_lines[@]}"
mysql_fragment agentshq agentshq agentshq "$AGENTSHQ_DB_PASSWORD"
# shellcheck disable=SC2046
mysql_fragment open-kudos open_kudos open_kudos "$OPEN_KUDOS_DB_PASSWORD" \
  $(cache_lines open-kudos "$OPEN_KUDOS_CACHE_PASSWORD") $(queue_lines open-kudos "$OPEN_KUDOS_QUEUE_PASSWORD") "${mail_lines[@]}"
mysql_fragment insight insight insight "$INSIGHT_DB_PASSWORD"
mysql_fragment togglebox togglebox togglebox "$TOGGLEBOX_DB_PASSWORD" "${mail_lines[@]}"
# shellcheck disable=SC2046
mysql_fragment openpay openpay openpay "$OPENPAY_DB_PASSWORD" \
  $(cache_lines openpay "$OPENPAY_CACHE_PASSWORD") $(queue_lines openpay "$OPENPAY_QUEUE_PASSWORD") \
  "S3_ENDPOINT=http://minio:9000" "S3_REGION=us-east-1" "S3_BUCKET=openpay" "S3_ACCESS_KEY=$OPENPAY_S3_ACCESS_KEY" "S3_SECRET_KEY=$OPENPAY_S3_SECRET_KEY" "S3_PATH_STYLE=true" "${mail_lines[@]}"
write_fragment ploon
write_fragment open-growth-group
# shellcheck disable=SC2046
mysql_fragment lokei lokei lokei "$LOKEI_DB_PASSWORD" \
  $(cache_lines lokei "$LOKEI_CACHE_PASSWORD") $(queue_lines lokei "$LOKEI_QUEUE_PASSWORD") "${mail_lines[@]}"
# shellcheck disable=SC2046
mysql_fragment albert albert albert "$ALBERT_DB_PASSWORD" \
  $(cache_lines albert "$ALBERT_CACHE_PASSWORD") $(queue_lines albert "$ALBERT_QUEUE_PASSWORD") \
  "QDRANT_URL=http://qdrant:6333" "QDRANT_API_KEY=$QDRANT_API_KEY" "QDRANT_COLLECTION_PREFIX=albert" "${mail_lines[@]}"
mysql_fragment record-cloud record_cloud record_cloud "$RECORD_CLOUD_DB_PASSWORD" \
  "S3_ENDPOINT=http://minio:9000" "S3_REGION=us-east-1" "S3_BUCKET=record-cloud" "S3_ACCESS_KEY=$RECORD_CLOUD_S3_ACCESS_KEY" "S3_SECRET_KEY=$RECORD_CLOUD_S3_SECRET_KEY" "S3_PATH_STYLE=true" "${mail_lines[@]}"
# shellcheck disable=SC2046
postgres_fragment plane plane plane "$PLANE_DB_PASSWORD" \
  $(valkey_lines) \
  "S3_ENDPOINT=http://minio:9000" "S3_REGION=us-east-1" "S3_BUCKET=plane" "S3_ACCESS_KEY=$PLANE_S3_ACCESS_KEY" "S3_SECRET_KEY=$PLANE_S3_SECRET_KEY" "S3_PATH_STYLE=true" \
  "RABBITMQ_HOST=rabbitmq" "RABBITMQ_PORT=5672" "RABBITMQ_VHOST=plane" "RABBITMQ_USERNAME=plane" "RABBITMQ_PASSWORD=$PLANE_RABBITMQ_PASSWORD"
# shellcheck disable=SC2046
postgres_fragment postiz postiz postiz "$POSTIZ_DB_PASSWORD" \
  $(cache_lines postiz "$POSTIZ_CACHE_PASSWORD") $(queue_lines postiz "$POSTIZ_QUEUE_PASSWORD") \
  "TEMPORAL_ADDRESS=temporal:7233" "TEMPORAL_NAMESPACE=postiz"
postgres_fragment nudgra-oss nudgra nudgra "$NUDGRA_DB_PASSWORD"
# shellcheck disable=SC2046
postgres_fragment n8n n8n n8n "$N8N_DB_PASSWORD" $(queue_lines n8n "$N8N_QUEUE_PASSWORD")
# shellcheck disable=SC2046
postgres_fragment twenty twenty twenty "$TWENTY_DB_PASSWORD" \
  $(cache_lines twenty "$TWENTY_CACHE_PASSWORD") \
  "S3_ENDPOINT=http://minio:9000" "S3_REGION=us-east-1" "S3_BUCKET=twenty" "S3_ACCESS_KEY=$TWENTY_S3_ACCESS_KEY" "S3_SECRET_KEY=$TWENTY_S3_SECRET_KEY" "S3_PATH_STYLE=true" "${mail_lines[@]}"

count=$(find "$fragments_dir" -maxdepth 1 -type f -name '*.shared.env' | wc -l | tr -d ' ')
[[ "$count" = "16" ]] || { echo "Internal error: expected 16 shared fragments, found $count" >&2; exit 1; }
echo "Generated infrastructure.env and 16 platform fragments in $output_dir (secrets not displayed)."
