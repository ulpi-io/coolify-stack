# Manual Coolify Import Handoff

No step in this document has been executed by this repository. These are operator instructions for a later Coolify import.

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

1. Replace every `example.invalid/...:replace-with-pinned-image` value with an image built from the named source repository and pinned to an immutable digest or commit tag.
2. Pin Postiz to a registry digest instead of `latest` when an immutable fork image is available.
3. Replace Nudgra's `OPERATOR_EMAIL_ALLOWLIST` placeholder.
4. Add optional OAuth, payment, social-provider, and API credentials only to the platform that owns them.
5. Configure `BACKUP_S3_BUCKET` and `BACKUP_S3_ENDPOINT` for storage outside this server before enabling the infrastructure `backup` profile. The shared MinIO instance is not an off-site backup target for itself.

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
| `platforms/kensi-ai` | `web` | `https://kensi.ai` |
| `platforms/agentshq` | `web` | `https://www.agentshq.sh` |
| `platforms/open-kudos` | `web` | `https://www.teamtoast.ai` |
| `platforms/insight` | `dashboard` | `https://clavinci.com` |
| `platforms/togglebox` | `admin` | `https://togglebox.dev` |
| `platforms/openpay` | `web` | `https://www.openpay.fyi` |
| `platforms/ploon` | `web` | `https://ploon.ai` |
| `platforms/open-growth-group` | `web` | `https://opengrowthgroup.co` |
| `platforms/lokei` | `web` | `https://lokei.dev` |
| `platforms/albert` | `web` | `https://albert.con.fyi` |
| `platforms/record-cloud` | `web` | `https://record.con.fyi` |
| `platforms/plane` | `proxy` | `https://pm.con.fyi` |
| `platforms/postiz` | `postiz` | `https://post.con.fyi` |
| `platforms/nudgra-oss` | `app` | `https://ig.con.fyi` |
| `platforms/n8n` | `n8n` | `https://workflow.con.fyi` |
| `platforms/twenty` | `twenty` | `https://crm.con.fyi` |

Coolify/Traefik owns public routing and TLS. Do not add host-published database or backing-service ports to these recipes.

## Laravel cache/queue compatibility note

Plane uses the shared Valkey service. Applications whose existing recipes use Redis receive the shared Redis endpoints. Laravel applications currently expose one Redis credential set for both cache and queue, so they use durable `redis-queue`; n8n and Postiz also use `redis-queue`, while Twenty uses `redis-cache`.

## 6. Acceptance checks after a later deployment

For each platform, verify schema initialization from an empty database, public HTTPS health, worker/queue execution, scheduler execution, object upload when applicable, and Mailpit capture when SMTP is configured. Then seed non-production sentinel data and prove backup/restore before treating the platform as production-ready.
