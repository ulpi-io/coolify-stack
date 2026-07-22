# Coolify Import Handoff

The repository workflow is `scripts/create-resources.sh`. It generates every environment, creates the Coolify resources, uploads values, and configures domains without deploying anything.

```bash
scripts/create-resources.sh --check
scripts/create-resources.sh --apply --reset --ssh-key /absolute/path/to/the/server/ssh/key
```

The remaining sections explain what the automation configures and are useful for manual verification.

## 1. Generate and store env files

Run locally on a trusted machine:

```bash
mkdir -p generated
infrastructure/generate-env.sh --output-dir generated

for slug in kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group lokei albert record-cloud plane postiz nudgra-oss n8n twenty; do
  platforms/$slug/generate-env.sh \
    --shared-env "generated/platforms/$slug.shared.env" \
    --output "generated/$slug.env"
done
```

Keep `generated/` outside version control and in an encrypted secret store. The infrastructure env is the recovery source for every database, ACL, bucket, RabbitMQ, Qdrant, and Temporal credential.

## 2. Complete required operator values

Before importing anything:

1. Add a read-only GitHub source token as the secret environment variable `GIT_AUTH_TOKEN` for repository-built platform stacks. It must be able to read the private repositories referenced by that stack.
2. Replace Nudgra's `OPERATOR_EMAIL_ALLOWLIST` placeholder.
3. Add optional OAuth, payment, social-provider, and API credentials only to the platform that owns them.
4. The backup destination values are intentionally blank. Configure `BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, `BACKUP_S3_SECRET_KEY`, and `BACKUP_S3_ENDPOINT` for storage outside this server before enabling the infrastructure `backup` profile. The shared MinIO instance is not an off-site backup target for itself.

## 3. Create the shared external network

Create one attachable Docker network named by `SHARED_NETWORK_NAME` (default `ogg-shared`) through the Coolify-supported mechanism. Do not reuse Coolify's internal management network. Import the infrastructure Compose first and attach all platform stacks to this same external network.

## 4. Import infrastructure

Import `infrastructure/compose.yaml` as one Coolify Docker Compose resource and load `generated/infrastructure.env` into its environment. Do not publish database, Valkey, MinIO, Qdrant, RabbitMQ, Elasticsearch, Temporal, or Mailpit SMTP ports.

The only operator UIs that may later receive restricted routes are Uptime Kuma, Mailpit UI, MinIO console, RabbitMQ management, and Temporal UI. They must not be public anonymous services.

Wait for the bootstrap jobs to finish successfully before importing applications. They create fresh empty databases/roles, Valkey ACLs, MinIO buckets/users/policies, and the shared service credentials. There is no data migration or old-volume reuse.

## 5. Import platforms

Import each platform folder as its own Coolify Compose resource using the matching generated env file:

| Folder | Public service | Domain |
| --- | --- | --- |
| `platforms/kensi-ai` | `web` | `https://www.kensi.ai` |
| `platforms/kensi-ai` | `nginx` | `https://api.kensi.ai` |
| `platforms/agentshq` | `web` | `https://www.agentshq.sh` |
| `platforms/agentshq` | `api` | `https://api.agentshq.sh` |
| `platforms/open-kudos` | `web` | `https://www.teamtoast.ai` |
| `platforms/open-kudos` | `nginx` | `https://api.teamtoast.ai` |
| `platforms/insight` | `dashboard` | `https://www.clavinci.com` |
| `platforms/insight` | `api` | `https://api.clavinci.com` |
| `platforms/togglebox` | `admin` | `https://www.togglebox.dev` |
| `platforms/togglebox` | `api` | `https://api.togglebox.dev` |
| `platforms/openpay` | `web` | `https://www.openpay.fyi` |
| `platforms/openpay` | `nginx` | `https://api.openpay.fyi` |
| `platforms/ploon` | `web` | `https://www.ploon.ai` |
| `platforms/open-growth-group` | `web` | `https://www.opengrowthgroup.co` |
| `platforms/lokei` | `web` | `https://www.lokei.dev` |
| `platforms/lokei` | `nginx` | `https://api.lokei.dev` |
| `platforms/lokei` | `relay` | `https://relay.lokei.dev` |
| `platforms/albert` | `web` | `https://www.albert.con.fyi` |
| `platforms/albert` | `nginx` | `https://api.albert.con.fyi` |
| `platforms/record-cloud` | `web` | `https://www.record.con.fyi` |
| `platforms/record-cloud` | `api` | `https://api.record.con.fyi` |
| `platforms/plane` | `proxy` | `https://www.pm.con.fyi` |
| `platforms/postiz` | `postiz` | `https://www.post.con.fyi` |
| `platforms/nudgra-oss` | `app` | `https://www.ig.con.fyi` |
| `platforms/n8n` | `n8n` | `https://www.workflow.con.fyi` |
| `platforms/twenty` | `twenty` | `https://www.crm.con.fyi` |

Coolify/Traefik owns public routing and TLS. Do not add host-published database or backing-service ports to these recipes.

## Laravel cache/queue compatibility note

Plane uses the shared Valkey service. Applications whose existing recipes use Redis receive the shared Redis endpoints. Laravel applications currently expose one Redis credential set for both cache and queue, so they use durable `redis-queue`; n8n and Postiz also use `redis-queue`, while Twenty uses `redis-cache`.

## 6. Acceptance checks after a later deployment

For each platform, verify schema initialization from an empty database, public HTTPS health, worker/queue execution, scheduler execution, object upload when applicable, and Mailpit capture when SMTP is configured. Then seed non-production sentinel data and prove backup/restore before treating the platform as production-ready.
