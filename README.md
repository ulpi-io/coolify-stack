# OGG Coolify Stack Recipes

This repository contains the complete production Compose shape for the OGG portfolio plus repeatable Coolify resource-creation and deployment workflows. It does not change DNS.

## Customer-facing platform table of contents

- [Kensi AI](https://www.kensi.ai) ([API](https://api.kensi.ai), [recipe](platforms/kensi-ai/))
- [AgentsHQ](https://www.agentshq.sh) ([API](https://api.agentshq.sh), [recipe](platforms/agentshq/))
- [TeamToast](https://www.teamtoast.ai) ([API](https://api.teamtoast.ai), [recipe](platforms/open-kudos/))
- [Clavinci](https://www.clavinci.com) ([API](https://api.clavinci.com), [recipe](platforms/insight/))
- [Togglebox](https://www.togglebox.dev) ([API](https://api.togglebox.dev), [recipe](platforms/togglebox/))
- [OpenPay](https://www.openpay.fyi) ([API](https://api.openpay.fyi), [recipe](platforms/openpay/))
- [Ploon](https://www.ploon.ai) ([recipe](platforms/ploon/))
- [Open Growth Group](https://www.opengrowthgroup.co) ([recipe](platforms/open-growth-group/))
- [Lokei](https://www.lokei.dev) ([API](https://api.lokei.dev), [recipe](platforms/lokei/))
- [Albert](https://www.albert.con.fyi) ([API](https://api.albert.con.fyi), [recipe](platforms/albert/))
- [Record Cloud](https://www.record.con.fyi) ([API](https://api.record.con.fyi), [recipe](platforms/record-cloud/))
- [Plane](https://pm.con.fyi) ([recipe](platforms/plane/))
- [Postiz](https://post.con.fyi) ([recipe](platforms/postiz/))
- [Nudgra OSS](https://ig.con.fyi) ([recipe](platforms/nudgra-oss/))
- [n8n](https://workflow.con.fyi) ([recipe](platforms/n8n/))
- [Twenty](https://crm.con.fyi) ([recipe](platforms/twenty/))
- Buzz relay (planned at `wss://buzz.con.fyi`; [recipe](platforms/buzz/); packaged desktop client connects over WSS)

## Production DNS A records

Every record below points to the production server at `68.183.135.86`. These are the exact hostnames configured in Coolify; apex domains are not part of the current routing map.

| DNS zone | Name | Type | Value |
| --- | --- | --- | --- |
| `kensi.ai` | `www` | `A` | `68.183.135.86` |
| `kensi.ai` | `api` | `A` | `68.183.135.86` |
| `agentshq.sh` | `www` | `A` | `68.183.135.86` |
| `agentshq.sh` | `api` | `A` | `68.183.135.86` |
| `teamtoast.ai` | `www` | `A` | `68.183.135.86` |
| `teamtoast.ai` | `api` | `A` | `68.183.135.86` |
| `clavinci.com` | `www` | `A` | `68.183.135.86` |
| `clavinci.com` | `api` | `A` | `68.183.135.86` |
| `togglebox.dev` | `www` | `A` | `68.183.135.86` |
| `togglebox.dev` | `api` | `A` | `68.183.135.86` |
| `openpay.fyi` | `www` | `A` | `68.183.135.86` |
| `openpay.fyi` | `api` | `A` | `68.183.135.86` |
| `ploon.ai` | `www` | `A` | `68.183.135.86` |
| `opengrowthgroup.co` | `www` | `A` | `68.183.135.86` |
| `lokei.dev` | `www` | `A` | `68.183.135.86` |
| `lokei.dev` | `api` | `A` | `68.183.135.86` |
| `lokei.dev` | `relay` | `A` | `68.183.135.86` |
| `con.fyi` | `www.albert` | `A` | `68.183.135.86` |
| `con.fyi` | `api.albert` | `A` | `68.183.135.86` |
| `con.fyi` | `www.record` | `A` | `68.183.135.86` |
| `con.fyi` | `api.record` | `A` | `68.183.135.86` |
| `con.fyi` | `pm` | `A` | `68.183.135.86` |
| `con.fyi` | `post` | `A` | `68.183.135.86` |
| `con.fyi` | `ig` | `A` | `68.183.135.86` |
| `con.fyi` | `workflow` | `A` | `68.183.135.86` |
| `con.fyi` | `crm` | `A` | `68.183.135.86` |

The Buzz recipe configures `buzz.con.fyi`, but that DNS record is not present
yet. Add `con.fyi` / `buzz` / `A` / `68.183.135.86` before deployment; this
repository intentionally does not mutate DNS.

## Layout

- `infrastructure/compose.yaml` contains the reusable backing services.
- `infrastructure/generate-env.sh` creates the infrastructure env plus 17 isolated platform fragments.
- `platforms/<slug>/compose.yaml` contains one logical application stack.
- `platforms/<slug>/generate-env.sh` combines that platform's shared fragment with platform secrets and canonical domain.
- `scripts/validate-all.sh` resolves every Compose file without starting containers.
- `scripts/create-resources.sh` generates environments and creates/configures the corresponding Coolify projects and Git Compose resources.
- `scripts/update-app-env.sh` safely adds or updates selected environment keys for one existing Coolify application.

There are exactly 18 Compose files and 18 env generators: one pair for infrastructure and one pair for each of the 17 platforms in `REPOSITORIES.md`.

## Shared infrastructure

The infrastructure Compose defines:

- MySQL 8.4 with a separate database and restricted user for each MySQL consumer.
- PostgreSQL 16 with a separate database/role for each PostgreSQL consumer and Temporal persistence.
- Valkey 8 for Plane, which already uses Valkey in its official stack.
- separate Redis 7.2 cache and durable-queue processes for applications whose current recipes use Redis.
- MinIO with per-application buckets, users, and bucket policies.
- Qdrant, RabbitMQ, Elasticsearch, and Temporal as reusable shared capabilities.
- Mailpit as the private SMTP sink for every detected SMTP consumer.
- Uptime Kuma for shared health monitoring.
- an opt-in, off-site `offen/docker-volume-backup` profile. It is intentionally disabled until its external S3 destination is configured.

Coolify itself and its own PostgreSQL, Redis, Traefik, Sentinel, and management network remain outside this stack.

## Generate local env artifacts

```bash
output_dir=$(mktemp -d)
infrastructure/generate-env.sh --output-dir "$output_dir"

platforms/kensi-ai/generate-env.sh \
  --shared-env "$output_dir/platforms/kensi-ai.shared.env" \
  --output "$output_dir/kensi-ai.env"
```

Generators create mode-`0600` files, do not print secret values, and refuse overwrite unless `--force` is passed.

## Validate without deployment

```bash
scripts/validate-all.sh
```

The validator checks the exact folder inventory, lints all shell scripts when ShellCheck is installed, creates throwaway env files, resolves all 18 Compose models, and rejects duplicated shared-service containers inside platform stacks. It never runs `docker compose up`.

## Create the Coolify resources

Validate the complete environment-generation workflow without contacting Coolify:

```bash
scripts/create-resources.sh --check
```

For a clean rebuild, set Coolify API Allowed IPs to exactly `127.0.0.1,::1`, then run:

```bash
scripts/create-resources.sh \
  --apply \
  --reset \
  --buzz-owner-pubkey "$BUZZ_OWNER_PUBKEY" \
  --ssh-key /absolute/path/to/the/server/ssh/key
```

Buzz is a closed relay by default. The owner public key is bootstrapped into its
membership table; keep the matching owner private key in the desktop client and
in a secure backup, never in this repository. To create a fresh owner identity,
run the pinned image's `buzz-admin generate-key` command on a trusted machine and
store the displayed secret before using its public key above.

```bash
docker run --rm --entrypoint /usr/local/bin/buzz-admin \
  ghcr.io/block/buzz@sha256:12763e38fd99fe8f4e63466a08ea8e3afbda4da0ebd1f51f0b57d78f9b082abe \
  generate-key
```

The command generates all secrets in a mode-`0600` temporary directory, opens the localhost-only API for the run, ensures the external `ogg-shared` Docker network exists, deletes only this repository's exact project names, and recreates the stack sequentially. For each resource it waits for Coolify's Compose parser to finish, applies service domains, removes all parser-generated placeholder/default rows, and uploads exactly one generated row per key. It rejects any duplicate key, surviving `required` placeholder, or mismatch from the generated env file before moving to the next project; Coolify-managed `SERVICE_*` routing variables are permitted in addition to the generated keys. It verifies that nothing is running, disables the API, revokes its temporary token, and removes the temporary files. This ordering avoids both Coolify 4.1.2's create-with-domains failure and its asynchronous environment-extraction behavior.

## Update one application's environment

Copy the example outside the repository, keep it private, and add only the
variables that need to be created or changed:

```bash
cp scripts/app-env.example /tmp/postiz-integrations.env
chmod 600 /tmp/postiz-integrations.env
${EDITOR:-vi} /tmp/postiz-integrations.env
```

Validate the app slug and file without contacting Coolify:

```bash
scripts/update-app-env.sh \
  --check \
  --app postiz \
  --env-file /tmp/postiz-integrations.env
```

Update Coolify and deploy only that application:

```bash
scripts/update-app-env.sh \
  --apply \
  --app postiz \
  --env-file /tmp/postiz-integrations.env \
  --ssh-key /absolute/path/to/the/server/ssh/key \
  --deploy
```

The updater preserves every unlisted variable, upserts each listed production
key exactly once, never prints values, and rejects duplicate keys or insecure
input-file permissions. Without `--deploy`, it saves the configuration and
prints the exact single-app deployment command instead. Empty values are
rejected unless `--allow-empty` is supplied intentionally. The localhost-only
Coolify API is disabled and the temporary API token is revoked on exit.

## Build sources

Existing published images are used for Plane, Postiz, n8n, Twenty, Buzz, and shared infrastructure. The other platform Compose files build directly from their GitHub repositories when Coolify deploys them. Private Git contexts use the BuildKit `GIT_AUTH_TOKEN` secret; the credential is used to fetch source and is not copied into an image layer.

Plane is pinned to the healthy server-deployed `v1.3.0` release. Postiz is pinned to the exact digest currently running healthily on the server (`sha256:1d5a5dc6b896747d1483c01dc2562165bd313ad601b32f6cabb7f7dd08a911a9`) instead of the mutable `latest` tag.

Buzz is pinned to the multi-architecture digest published for upstream commit
`3e48f1b` (`sha256:12763e38fd99fe8f4e63466a08ea8e3afbda4da0ebd1f51f0b57d78f9b082abe`).
The relay uses isolated shared PostgreSQL, durable Redis, and MinIO credentials,
plus its own persistent git scratch volume. Install the packaged Buzz desktop
client and connect it to `wss://buzz.con.fyi`.

See `COOLIFY_IMPORT.md` for the manual import order and service/domain map.
