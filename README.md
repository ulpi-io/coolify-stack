# OGG Coolify Stack Recipes

This repository contains the complete production Compose shape for the OGG portfolio. It creates deployment artifacts only. It does not call Coolify, change DNS, connect to the production server, or deploy containers.

## Layout

- `infrastructure/compose.yaml` contains the reusable backing services.
- `infrastructure/generate-env.sh` creates the infrastructure env plus 16 isolated platform fragments.
- `platforms/<slug>/compose.yaml` contains one logical application stack.
- `platforms/<slug>/generate-env.sh` combines that platform's shared fragment with platform secrets and canonical domain.
- `scripts/validate-all.sh` resolves every Compose file without starting containers.

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

## Required image handoff

The third-party recipe images are preserved at the versions recorded in the source recipes. First-party components do not currently have a confirmed common registry/tag contract, so their generated env files deliberately use `example.invalid/...:replace-with-pinned-image` values. Replace every such value with a built, immutable image reference before importing the platform into Coolify. Do not silently turn those placeholders into guessed GHCR paths.

Postiz currently follows its fork's `ghcr.io/gitroomhq/postiz-app:latest` reference. Resolve and record a registry digest before production deployment if the fork does not publish an immutable release tag.

See `COOLIFY_IMPORT.md` for the manual import order and service/domain map.
