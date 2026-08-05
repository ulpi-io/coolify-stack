# Coolify Import Handoff

The repository workflow is `scripts/create-resources.sh`. It generates every environment, creates the Coolify resources, uploads values, and configures domains without deploying anything.

```bash
scripts/create-resources.sh --check
scripts/create-resources.sh --apply --reset \
  --buzz-owner-pubkey "$BUZZ_OWNER_PUBKEY" \
  --qm-claude-token-file /secure/path/claude-setup-token \
  --qm-resend-key-file /secure/path/resend-api-key \
  --ssh-key /absolute/path/to/the/server/ssh/key
scripts/create-resources.sh --apply --only social-reply \
  --env-file /secure/path/social-reply.env \
  --ssh-key /absolute/path/to/the/server/ssh/key
scripts/create-resources.sh --apply --only qm \
  --env-file /secure/path/qm.env \
  --ssh-key /absolute/path/to/the/server/ssh/key
```

The remaining sections explain what the automation configures and are useful for manual verification.

## 1. Generate and store env files

Run locally on a trusted machine:

```bash
mkdir -p generated
infrastructure/generate-env.sh --output-dir generated

for slug in kensi-ai agentshq open-kudos insight togglebox openpay ploon open-growth-group con-fyi lokei albert record-cloud plane postiz nudgra-oss n8n twenty social-reply; do
  platforms/$slug/generate-env.sh \
    --shared-env "generated/platforms/$slug.shared.env" \
    --output "generated/$slug.env"
done

platforms/buzz/generate-env.sh \
  --shared-env generated/platforms/buzz.shared.env \
  --output generated/buzz.env \
  --owner-pubkey "$BUZZ_OWNER_PUBKEY"

platforms/qm/generate-env.sh \
  --shared-env generated/platforms/qm.shared.env \
  --output generated/qm.env \
  --claude-token-file /secure/path/claude-setup-token \
  --resend-key-file /secure/path/resend-api-key
```

Keep `generated/` outside version control and in an encrypted secret store. The infrastructure env is the recovery source for every database, ACL, bucket, RabbitMQ, Qdrant, and Temporal credential.

## 2. Complete required operator values

Before importing anything:

1. Add a read-only GitHub source token as the secret environment variable `GIT_AUTH_TOKEN` for repository-built platform stacks. It must be able to read the private repositories referenced by that stack.
2. Replace Nudgra's `OPERATOR_EMAIL_ALLOWLIST` placeholder.
3. Supply Buzz's 64-character hex Nostr owner public key and securely retain the matching private key outside the server recipe.
4. SocialReply's operator allowlist defaults to the `--operator-email` value (`cip@opengrowthgroup.co` by default). Confirm it before import.
5. Add optional OAuth, payment, social-provider, and API credentials only to the platform that owns them. SocialReply declares optional provider secrets as pass-through variables so an unset secret remains absent rather than becoming a misleading blank credential.
6. QM requires a mode-`0600` Claude setup-token file and Resend API-key file. Its dedicated Docker-in-Docker service is privileged but does not mount the production host Docker socket.
7. The backup destination values are intentionally blank. Configure `BACKUP_S3_BUCKET`, `BACKUP_S3_ACCESS_KEY`, `BACKUP_S3_SECRET_KEY`, and `BACKUP_S3_ENDPOINT` for storage outside this server before enabling the infrastructure `backup` profile. The shared MinIO instance is not an off-site backup target for itself.

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
| `platforms/con-fyi` | `web` | `https://con.fyi` |
| `platforms/lokei` | `web` | `https://www.lokei.dev` |
| `platforms/lokei` | `nginx` | `https://api.lokei.dev` |
| `platforms/lokei` | `relay` | `https://relay.lokei.dev` |
| `platforms/albert` | `web` | `https://www.albert.con.fyi` |
| `platforms/albert` | `nginx` | `https://api.albert.con.fyi` |
| `platforms/record-cloud` | `web` | `https://www.record.con.fyi` |
| `platforms/record-cloud` | `api` | `https://api.record.con.fyi` |
| `platforms/plane` | `proxy` | `https://pm.con.fyi` |
| `platforms/postiz` | `postiz` | `https://post.con.fyi` |
| `platforms/nudgra-oss` | `app` | `https://ig.con.fyi` |
| `platforms/n8n` | `n8n` | `https://workflow.con.fyi` |
| `platforms/twenty` | `twenty` | `https://crm.con.fyi` |
| `platforms/buzz` | `relay` | `https://buzz.con.fyi` |
| `platforms/social-reply` | `web` | `https://socialreply.ai` |
| `platforms/social-reply` | `nginx` | `https://api.socialreply.ai` |
| `platforms/social-reply` | `reverb` | `https://ws.socialreply.ai` |
| `platforms/qm` | `portal` | `https://agents.con.fyi` |

Coolify/Traefik owns public routing and TLS. Do not add host-published database or backing-service ports to these recipes.

## Laravel cache/queue compatibility note

Plane uses the shared Valkey service. Applications whose existing recipes use Redis receive the shared Redis endpoints. Laravel applications currently expose one Redis credential set for both cache and queue, so they use durable `redis-queue`; n8n, Postiz, Buzz, and SocialReply also use `redis-queue`, while Twenty uses `redis-cache`. All PostgreSQL consumers use isolated databases and restricted roles on shared PostgreSQL 17. SocialReply additionally enables pgvector inside only its own database.

## 6. Acceptance checks after a later deployment

For each platform, verify schema initialization from an empty database, public HTTPS health, worker/queue execution, scheduler execution, object upload when applicable, and Mailpit capture when SMTP is configured. Then seed non-production sentinel data and prove backup/restore before treating the platform as production-ready.

For Buzz specifically, also connect the packaged desktop client to
`wss://buzz.con.fyi`, confirm the configured owner is bootstrapped, prove an
unlisted identity is rejected, upload/download media, and exercise a git repo
round trip before closing its production gate.

For SocialReply specifically, run migrations twice against the fresh pgvector
database, verify the Laravel `/up` route, Next.js `/en` render, Horizon status,
scheduler enumeration, and the Reverb `/up` route, then exercise one queue job,
one S3 object round trip, one captured email, and one authenticated Sanctum
session across `socialreply.ai` and `api.socialreply.ai`.
