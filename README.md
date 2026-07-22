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
- [Plane](https://www.pm.con.fyi) ([recipe](platforms/plane/))
- [Postiz](https://www.post.con.fyi) ([recipe](platforms/postiz/))
- [Nudgra OSS](https://www.ig.con.fyi) ([recipe](platforms/nudgra-oss/))
- [n8n](https://www.workflow.con.fyi) ([recipe](platforms/n8n/))
- [Twenty](https://www.crm.con.fyi) ([recipe](platforms/twenty/))

## Layout

- `infrastructure/compose.yaml` contains the reusable backing services.
- `infrastructure/generate-env.sh` creates the infrastructure env plus 16 isolated platform fragments.
- `platforms/<slug>/compose.yaml` contains one logical application stack.
- `platforms/<slug>/generate-env.sh` combines that platform's shared fragment with platform secrets and canonical domain.
- `scripts/validate-all.sh` resolves every Compose file without starting containers.
- `scripts/create-resources.sh` generates environments and creates/configures the corresponding Coolify projects and Git Compose resources.

There are exactly 17 Compose files and 17 env generators: one pair for infrastructure and one pair for each of the 16 platforms in `REPOSITORIES.md`.

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

The validator checks the exact folder inventory, lints all shell scripts when ShellCheck is installed, creates throwaway env files, resolves all 17 Compose models, and rejects duplicated shared-service containers inside platform stacks. It never runs `docker compose up`.

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
  --ssh-key /absolute/path/to/the/server/ssh/key
```

The command generates all secrets in a mode-`0600` temporary directory, opens the localhost-only API for the run, ensures the external `ogg-shared` Docker network exists, deletes only this repository's exact project names, and recreates the stack sequentially. For each resource it waits for Coolify's Compose parser to finish, applies service domains, removes all parser-generated placeholder/default rows, and uploads exactly one generated row per key. It rejects any duplicate key, surviving `required` placeholder, or mismatch from the generated env file before moving to the next project; Coolify-managed `SERVICE_*` routing variables are permitted in addition to the generated keys. It verifies that nothing is running, disables the API, revokes its temporary token, and removes the temporary files. This ordering avoids both Coolify 4.1.2's create-with-domains failure and its asynchronous environment-extraction behavior.

## Build sources

Existing published images are used for Plane, Postiz, n8n, Twenty, and shared infrastructure. The other platform Compose files build directly from their GitHub repositories when Coolify deploys them. Private Git contexts use the BuildKit `GIT_AUTH_TOKEN` secret; the credential is used to fetch source and is not copied into an image layer.

Plane is pinned to the healthy server-deployed `v1.3.0` release. Postiz is pinned to the exact digest currently running healthily on the server (`sha256:1d5a5dc6b896747d1483c01dc2562165bd313ad601b32f6cabb7f7dd08a911a9`) instead of the mutable `latest` tag.

See `COOLIFY_IMPORT.md` for the manual import order and service/domain map.
