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
- [ConFYI](https://con.fyi) ([recipe](platforms/con-fyi/))
- [Lokei](https://www.lokei.dev) ([API](https://api.lokei.dev), [recipe](platforms/lokei/))
- [Albert](https://www.albert.con.fyi) ([API](https://api.albert.con.fyi), [recipe](platforms/albert/))
- [Record Cloud](https://www.record.con.fyi) ([API](https://api.record.con.fyi), [recipe](platforms/record-cloud/))
- [Plane](https://pm.con.fyi) ([recipe](platforms/plane/))
- [Postiz](https://post.con.fyi) ([recipe](platforms/postiz/))
- [Nudgra OSS](https://ig.con.fyi) ([recipe](platforms/nudgra-oss/))
- [n8n](https://workflow.con.fyi) ([recipe](platforms/n8n/))
- [Twenty](https://crm.con.fyi) ([recipe](platforms/twenty/))
- Buzz relay (planned at `wss://buzz.con.fyi`; [recipe](platforms/buzz/); packaged desktop client connects over WSS)
- [SocialReply](https://www.socialreply.ai) ([API](https://api.socialreply.ai), [realtime](https://ws.socialreply.ai), [recipe](platforms/social-reply/))
- [QM Agents](https://agents.con.fyi) ([recipe](platforms/qm/))

## Production DNS records

Every address record below points to the production server at `68.183.135.86`;
the SocialReply `www` CNAME resolves through its apex record. These are the
exact hostnames configured in Coolify, and `@` denotes a zone apex.

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
| `con.fyi` | `@` | `A` | `68.183.135.86` |
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
| `con.fyi` | `agents` | `A` | `68.183.135.86` |
| `socialreply.ai` | `@` | `A` | `68.183.135.86` |
| `socialreply.ai` | `www` | `CNAME` | `@` |
| `socialreply.ai` | `api` | `A` | `68.183.135.86` |
| `socialreply.ai` | `ws` | `A` | `68.183.135.86` |

The Buzz recipe configures `buzz.con.fyi`, but that DNS record is not present
yet. Add `con.fyi` / `buzz` / `A` / `68.183.135.86` before deployment; this
repository intentionally does not mutate DNS.

The SocialReply recipe uses `www.socialreply.ai` as its canonical website and
permanently redirects `socialreply.ai` to the same path on that host. Before
deployment, point the apex, API, and WebSocket `A` records to `68.183.135.86`
and point the `www` CNAME at the apex. All four HTTP hostnames permanently
redirect to HTTPS; this repository does not create DNS.

The QM recipe configures `agents.con.fyi`. Add `con.fyi` / `agents` / `A` /
`68.183.135.86` before public use; this repository does not create that record.

## Layout

- `infrastructure/compose.yaml` contains the reusable backing services.
- `infrastructure/generate-env.sh` creates the infrastructure env plus 20 isolated platform fragments.
- `platforms/<slug>/compose.yaml` contains one logical application stack.
- `platforms/<slug>/generate-env.sh` combines that platform's shared fragment with platform secrets and canonical domain.
- `scripts/validate-all.sh` resolves every Compose file without starting containers.
- `scripts/create-resources.sh` generates environments and creates/configures the corresponding Coolify projects and Git Compose resources.
- `scripts/update-app-env.sh` safely adds or updates selected environment keys for one existing Coolify application.

There are exactly 21 Compose files and 21 env generators: one pair for infrastructure and one pair for each of the 20 platforms in `REPOSITORIES.md`.

## Shared infrastructure

The infrastructure Compose defines:

- MySQL 8.4 with a separate database and restricted user for each MySQL consumer.
- PostgreSQL 17 with pgvector, a separate database/role for each PostgreSQL consumer, and Temporal persistence.
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

The validator checks the exact folder inventory, lints all shell scripts when ShellCheck is installed, creates throwaway env files, resolves all 21 Compose models, and rejects accidental duplication of shared-service containers inside platform stacks. It also enforces the shared PostgreSQL 17 plus pgvector contract used by SocialReply, QM, and the existing PostgreSQL consumers. It never runs `docker compose up`.

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
  --qm-claude-token-file /secure/path/claude-setup-token \
  --qm-resend-key-file /secure/path/resend-api-key \
  --ssh-key /absolute/path/to/the/server/ssh/key
```

Create one missing resource without deleting or changing any other project:

```bash
scripts/create-resources.sh \
  --apply \
  --only social-reply \
  --env-file /secure/path/social-reply.env \
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

The command generates all secrets in a mode-`0600` temporary directory, opens the localhost-only API for the run, and ensures the external `ogg-shared` Docker network exists. Full `--reset` mode deletes only this repository's exact project names and recreates the stack sequentially; `--only` requires its target project to be absent unless `--reset` is also supplied. For each selected resource it waits for Coolify's Compose parser to finish, applies service domains, removes all parser-generated placeholder/default rows, and uploads exactly one generated row per key. It rejects any duplicate key, surviving `required` placeholder, or mismatch from the generated env file before moving to the next project; Coolify-managed `SERVICE_*` routing variables are permitted in addition to the generated keys. It verifies that nothing is running, disables the API, revokes its temporary token, and removes the temporary files. This ordering avoids both Coolify 4.1.2's create-with-domains failure and its asynchronous environment-extraction behavior.

Private source builds use `GIT_AUTH_TOKEN` when it is exported; otherwise the
resource creator falls back to the active GitHub CLI token. The credential is
loaded as a BuildKit secret and is not copied into application images.

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

Postiz's Facebook and Facebook Business-linked Instagram providers use
`FACEBOOK_APP_ID` and `FACEBOOK_APP_SECRET`. The Meta app must allow these
OAuth redirect URIs:

```text
https://post.con.fyi/integrations/social/facebook
https://post.con.fyi/integrations/social/instagram
```

Postiz's `Instagram (Standalone)` provider instead uses `INSTAGRAM_APP_ID` and
`INSTAGRAM_APP_SECRET`, copied from Meta's Instagram API setup screen. Its OAuth
redirect URI is:

```text
https://post.con.fyi/integrations/social/instagram-standalone
```

Do not put Instagram App credentials in the `FACEBOOK_*` variables: Facebook
OAuth rejects that Instagram App ID with `PLATFORM__INVALID_APP_ID`. Configure
either credential pair through the scoped updater above.

These are OAuth callbacks, not Meta webhook endpoints; the deployed Postiz
provider does not implement Meta's webhook verify-token challenge.

Postiz's YouTube provider uses `YOUTUBE_CLIENT_ID` and
`YOUTUBE_CLIENT_SECRET`. Configure the OAuth client as a Google web application
with this exact authorized redirect URI:

```text
https://post.con.fyi/integrations/social/youtube
```

Postiz's TikTok provider uses `TIKTOK_CLIENT_ID` and `TIKTOK_CLIENT_SECRET`.
Configure TikTok Login Kit with this exact redirect URI:

```text
https://post.con.fyi/integrations/social/tiktok
```

TikTok `pull_by_url` media transfer also requires domain verification for
`post.con.fyi`, which covers Postiz media URLs under `/uploads/`.

Postiz's LinkedIn profile and company-page providers share
`LINKEDIN_CLIENT_ID` and `LINKEDIN_CLIENT_SECRET`. Configure both exact OAuth
redirect URLs in the LinkedIn application:

```text
https://post.con.fyi/integrations/social/linkedin
https://post.con.fyi/integrations/social/linkedin-page
```

## Build sources

Existing published images are used for Plane, Postiz, n8n, Twenty, Buzz, and shared infrastructure. The other platform Compose files build directly from their GitHub repositories when Coolify deploys them. Private Git contexts use the BuildKit `GIT_AUTH_TOKEN` secret; the credential is used to fetch source and is not copied into an image layer.

Plane is pinned to the healthy server-deployed `v1.3.0` release. Postiz is pinned to the exact digest currently running healthily on the server (`sha256:1d5a5dc6b896747d1483c01dc2562165bd313ad601b32f6cabb7f7dd08a911a9`) instead of the mutable `latest` tag.

Buzz is pinned to the multi-architecture digest published for upstream commit
`3e48f1b` (`sha256:12763e38fd99fe8f4e63466a08ea8e3afbda4da0ebd1f51f0b57d78f9b082abe`).
The relay uses isolated shared PostgreSQL, durable Redis, and MinIO credentials,
plus its own persistent git scratch volume. Install the packaged Buzz desktop
client and connect it to `wss://buzz.con.fyi`.

SocialReply builds its Laravel API, nginx sidecar, Horizon worker, scheduler,
Reverb server, and Next.js web application from the immutable audited source
commit recorded in `platforms/social-reply/generate-env.sh`. Its isolated
database and role use the shared PostgreSQL 17 service; pgvector is enabled only
in that database. Durable Redis, MinIO object storage, and Mailpit are also
shared with application-specific credentials and namespaces.

SocialReply production delivery is exact-SHA and single-resource scoped. After
SocialReply's backend and frontend CI jobs pass on `main`, its workflow sends a
signed repository dispatch to this repository. The receiver verifies that the
requested SHA is still SocialReply's current `main`, promotes only
`SOCIAL_REPLY_SOURCE_REF`, validates every Compose model, and asks the server's
forced-command deployment gate to replace only the existing SocialReply
resource. The gate rejects every other slug and command, keeps Coolify's API
localhost-only, waits for all SocialReply services and migrations, exercises
the three internal HTTPS routes, and fails if any non-SocialReply running
container changes during the deployment. Shared infrastructure is never part
of this workflow.

QM builds the core, portal, web UI, admin, and auth services from the immutable
private `ulpi-io/qm` commit recorded in `platforms/qm/generate-env.sh`. It uses
an isolated database and role on shared PostgreSQL 17. Agent computers run in
a dedicated privileged Docker-in-Docker daemon whose TCP endpoint is bound only
to its own loopback namespace; the production host Docker socket is never
mounted. A pinned TCP proxy is the only QM service attached to the shared
network and bridges database traffic from QM's private network to PostgreSQL.
Claude runs through `CLAUDE_CODE_OAUTH_TOKEN`, and Resend handles the built-in
broker's one-time sign-in email. The sign-in allowlist includes
`cip@opengrowthgroup.co` and `tania@opengrowthgroup.co`; only the configured
administrator receives `org_admin`. Sign-in messages are sent as
`Agents <no-reply@agents.con.fyi>` from the Agents sending domain.

The pinned QM dependency tree currently reports unresolved high-severity
production findings, including transitive `undici` findings with no upstream fix. The
production image installs the immutable lockfile but does not run `npm audit`
as a build gate; this exception was explicitly accepted for this deployment.
Re-evaluate and remove the exception when the private fork updates its
dependencies.

See `COOLIFY_IMPORT.md` for the manual import order and service/domain map.
