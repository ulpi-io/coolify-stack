# Agent Prompt: Build a Coolify Deployment System with Shared Infrastructure and Automatic Deployments

**Version 3.** This version incorporates the production-hardening additions from v2 and corrects the deployment model, networking assumptions, Valkey isolation, rollback, backup, and Coolify API behaviour.

---

## Role

Act as a senior platform engineer and DevOps architect.

You will receive a list of public and private Git repository URLs. Some are first-party applications that I control; others are third-party open-source applications I want to self-host.

Your job is to inspect every repository and build a maintainable deployment system for Coolify that:

1. Uses shared PostgreSQL and Valkey where technically safe.
2. Gives every application its own database, credentials, storage allocation, and runtime configuration.
3. Deploys each application through a Coolify-compatible Docker Compose file.
4. Automatically deploys first-party applications after tested code is pushed or merged to `main`.
5. Avoids unnecessary source forks.
6. Produces all required files, scripts, workflows, documentation, and pull requests.

Do not stop at recommendations. Implement everything possible with the access provided.

---

# Operating Rules for You, the Agent

These govern how you work, not what you build. They matter more than any single technical section.

## Verification over assumption

Every command, path, port, environment-variable name, image tag, migration command, worker command, health check, storage path, and startup command written into a Compose file or script must be traceable to a specific file in a specific repository at a specific commit.

If you cannot verify a value:

- write `UNVERIFIED` next to it in the research file,
- do not silently infer it from framework conventions,
- add it to `docs/MANUAL_ACTIONS.md`,
- do not claim the related deployment or validation step passed.

Never infer a migration command merely because an application uses a known framework.

## Never fabricate results

If you did not run a test, its status is `PENDING`.

If a command failed:

- preserve the relevant output,
- report the failure accurately,
- do not describe intended behaviour as observed behaviour.

## Work incrementally and checkpoint to disk

Process repositories one at a time.

After each repository:

1. Write findings to `docs/research/<slug>.md`.
2. Update the application matrix.
3. Commit the changes.

Do not hold research for many repositories in working memory before writing anything.

If interrupted, the next run must be able to resume from committed files alone.

## Stop and ask when the blast radius is large

Ask before:

- dropping or altering an existing production database,
- changing shared infrastructure already serving traffic,
- rotating a credential currently in use,
- force-pushing,
- merging,
- deleting any Coolify resource,
- destroying persistent volumes,
- changing a production domain,
- replacing a production PostgreSQL image,
- performing a destructive or irreversible migration.

## Report progress at each execution-order step

Use this format:

```text
Step:
Completed:
Verified:
Blocked:
Next:
```

## Prefer the smallest thing that works

Do not introduce Kubernetes, Terraform, Kafka, custom schedulers, service meshes, or a custom deployment control plane unless a verified application requirement forces it.

---

# Inputs

You will receive:

```yaml
repositories:
  - url: <PUBLIC_OR_PRIVATE_GIT_URL>
    name: <OPTIONAL_NAME>
    ownership: first-party | third-party | unknown
    domain: <OPTIONAL_DOMAIN>
    environment: production | staging | both
    ref: <OPTIONAL_TAG_OR_COMMIT>

coolify:
  base_url: <COOLIFY_BASE_URL>
  version: <OPTIONAL_COOLIFY_VERSION>
  api_token: <OPTIONAL_API_TOKEN>
  project_uuid: <OPTIONAL_PROJECT_UUID>
  environment_uuid: <OPTIONAL_ENVIRONMENT_UUID>
  server_uuid: <OPTIONAL_SERVER_UUID>
  destination_uuid: <OPTIONAL_DESTINATION_UUID>
  github_app_uuid: <OPTIONAL_GITHUB_APP_UUID>

github:
  organisation: <GITHUB_ORGANISATION>
  deployment_repository_name: coolify-deployments

infrastructure:
  postgres_version: "16"
  postgres_image: <OPTIONAL_IMAGE>
  valkey_version: "8"
  base_domain: <BASE_DOMAIN>
  wildcard_dns_configured: true | false | unknown
  server_arch: amd64 | arm64
  server_resources:
    cpus: <N>
    memory_gb: <N>
  backup_bucket: <OPTIONAL_S3_BUCKET>
  backup_endpoint: <OPTIONAL_S3_ENDPOINT>
```

When a value is missing:

- do not invent it,
- continue with placeholders,
- produce `docs/MANUAL_ACTIONS.md` with the exact remaining steps,
- do not block unrelated work because one credential or UUID is unavailable.

## Coolify version gating

Before relying on version-dependent behaviour:

1. Call `GET /api/v1/version` when API access exists.
2. Record the returned version in `docs/COOLIFY_SETUP.md`.
3. When API access does not exist, record the version as `UNKNOWN`.

Magic environment variables in Compose-from-Git deployments require a compatible Coolify release. Do not assume support from the prompt alone.

If unsupported or unknown:

- configure domains through the Coolify UI or API,
- do not rely on `SERVICE_FQDN_*` or related magic variables,
- add the exact domain-configuration step to `docs/MANUAL_ACTIONS.md`.

---

# Required Architecture

Create one central deployment repository:

```text
coolify-deployments/
├── README.md
├── catalog/
│   ├── applications.yaml
│   └── allocations.yaml
├── shared-infrastructure/
│   ├── compose.yaml
│   ├── .env.example
│   └── README.md
├── applications/
│   ├── <application-slug>/
│   │   ├── compose.yaml
│   │   ├── .env.example
│   │   ├── .env.validate
│   │   ├── README.md
│   │   ├── VERSION
│   │   ├── patches/
│   │   └── scripts/
│   └── ...
├── scripts/
│   ├── provision-application
│   ├── deprovision-application
│   ├── rotate-secret
│   ├── validate-all
│   ├── smoke-test
│   ├── backup-database
│   └── restore-database
├── docs/
│   ├── ARCHITECTURE.md
│   ├── APPLICATION_MATRIX.md
│   ├── DATABASE_AND_CACHE_ALLOCATIONS.md
│   ├── COOLIFY_SETUP.md
│   ├── CI_CD.md
│   ├── BACKUP_AND_RESTORE.md
│   ├── OPERATIONS.md
│   ├── SECURITY.md
│   ├── RUNBOOKS.md
│   ├── MANUAL_ACTIONS.md
│   └── research/
│       └── <slug>.md
├── state/
│   └── .gitignore
└── .github/
    ├── workflows/
    │   ├── validate-deployments.yml
    │   └── dependency-updates.yml
    └── dependabot.yml
```

Use this separation:

```text
First-party repositories
├── application source
├── tests
├── production Dockerfile
└── GitHub Actions that build and publish images

Third-party repositories
└── upstream source and releases

coolify-deployments
├── shared infrastructure
├── application Compose files
├── version pins
├── provisioning scripts
└── operational documentation

Coolify
├── runs all stacks
├── manages domains and TLS
├── connects stacks to its predefined network
├── stores the operational copy of runtime secrets
└── receives deployment triggers

GHCR
└── stores first-party and custom-built images
```

---

# Source of Truth

| Data | Authoritative location | Notes |
|---|---|---|
| Applications, deployment class, domain, environment | `catalog/applications.yaml` | Human-edited |
| Database names, role names, connection limits, Valkey allocations, bucket names, Coolify UUIDs, internal hostnames | `catalog/allocations.yaml` | Machine-written; never contains secrets |
| Runtime secrets | Coolify environment variables | Operational source of truth |
| Disaster-recovery copies of critical secrets | Approved external encrypted secret store and Coolify backup | Must survive loss of the Coolify server |
| Local rendered `.env` files | `state/`, gitignored | Disposable cache only |
| Third-party image versions and digests | `applications/<slug>/VERSION` and `compose.yaml` | Changed only by reviewed pull request |
| First-party deployed image tag | Coolify `IMAGE_TAG` environment variable | Uses immutable `sha-*` tag for deployments |

The provisioner must rebuild a working deployment from:

```text
Git catalog
+ Coolify runtime configuration
+ external encrypted recovery material
```

It must not depend on an operator's laptop or on files that exist only under `state/`.

## Coolify disaster recovery

Coolify is the operational source of truth for runtime secrets, but it must not be the only surviving copy.

At minimum:

- configure off-server backups of Coolify's own database and configuration,
- verify a Coolify restore procedure,
- keep critical recovery credentials in Vaultwarden or another approved encrypted secret store,
- ensure loss of the Coolify server does not permanently destroy database passwords, application encryption keys, OAuth secrets, or deployment tokens.

The `state/` directory is never a disaster-recovery source.

---

# Core Decision

Do not fork every application.

Use this decision tree:

```text
Does upstream provide a suitable production image?
├── Yes
│   └── Use the pinned upstream image in coolify-deployments
└── No
    ├── First-party repository
    │   └── Add a Dockerfile, build in GitHub Actions, publish to GHCR
    ├── Third-party with no code changes required
    │   └── Create a small build repository or use a pinned submodule
    ├── Small modifications required
    │   └── Maintain explicit patch files
    └── Significant source modifications required
        └── Maintain a proper fork
```

A suitable image must be:

- published for the server architecture,
- versioned with immutable release tags or digests,
- actively maintained,
- compatible with the required runtime,
- not dependent on privileged mode,
- not dependent on unrestricted Docker socket access,
- not dependent on host networking unless explicitly justified.

Record the evidence and reason for every verdict.

Never deploy third-party software directly from an unpinned `main` branch.

---

# Delivery Milestones

This project has two milestones.

## Milestone 1: Operational deployment

Complete this first.

1. Confirm access and Coolify version.
2. Inspect and classify repositories.
3. Create the deployment repository.
4. Decide which applications can share PostgreSQL and Valkey.
5. Deploy shared infrastructure.
6. Create one database and role per compatible application.
7. Create one Coolify-ready Compose definition per application.
8. Prove one representative application end to end.
9. Configure first-party GHCR builds and Coolify deployment from `main`.
10. Configure basic off-server backups.
11. Record every unverified or deferred hardening item.

Do not block a working deployment on Milestone 2 unless the missing hardening item creates an immediate data-loss or security risk.

## Milestone 2: Production hardening

After Milestone 1 works:

- implement Valkey ACL isolation where supported,
- complete PostgreSQL connection budgeting,
- add PgBouncer if measured or calculated requirements justify it,
- implement credential-rotation automation,
- perform rollback exercises,
- perform database-restore exercises,
- test full-server reboot recovery,
- verify cross-database isolation,
- add worker-heartbeat monitoring,
- complete failure-mode runbooks,
- configure branch protection across first-party repositories,
- test Coolify disaster recovery.

Record deferred Milestone 2 work in `docs/MANUAL_ACTIONS.md` and `docs/RUNBOOKS.md`.

---

# Shared Infrastructure

Create shared infrastructure containing:

```text
PostgreSQL 16
Valkey 8 for disposable cache
Valkey 8 for durable queues
Optional shared S3-compatible object storage
```

Do not include Caddy, Nginx, or Traefik because Coolify already provides the reverse proxy.

---

# PostgreSQL Deployment Mechanism

Choose one option explicitly and document it in `docs/ARCHITECTURE.md`.

## Option A: Coolify-managed PostgreSQL resource

Advantages:

- Coolify-managed lifecycle,
- built-in scheduled backup integration,
- retention and S3-compatible upload through Coolify,
- easier operational visibility.

Default to Option A unless a verified requirement forces Option B.

## Option B: PostgreSQL inside a custom Compose stack

Use only when required by:

- a custom PostgreSQL image,
- extensions not available in the managed resource,
- custom server configuration,
- multiple PostgreSQL instances,
- another verified deployment constraint.

If Option B is chosen:

- Coolify's database-resource backup UI does not manage it,
- create and schedule your own backup job,
- upload backups off-server,
- test restoration,
- document the complete process.

A manual `pg_dump` command is not sufficient. The backup job must be scheduled and monitored.

---

# PostgreSQL Design

Use:

- one PostgreSQL server where safe,
- one database per application per environment,
- one restricted login role per application per environment,
- one unique password per role,
- no public `5432`,
- persistent storage,
- off-server backups,
- measured or calculated connection limits.

Naming convention:

```text
Database: <prefix>_<app>_<environment>
Role:     <prefix>_<app>_<environment>
```

Examples:

```text
ogg_plane_prod / ogg_plane_prod
ogg_twenty_prod / ogg_twenty_prod
ogg_n8n_prod / ogg_n8n_prod
```

Production and staging must not share the same role.

Provision each application as administrator:

```sql
CREATE ROLE <role>
    LOGIN
    PASSWORD '<generated-password>'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    CONNECTION LIMIT <n>;

CREATE DATABASE <database>
    OWNER <role>
    ENCODING 'UTF8'
    TEMPLATE template0;

REVOKE ALL ON DATABASE <database> FROM PUBLIC;
GRANT CONNECT ON DATABASE <database> TO <role>;
```

Then connect to the application database as administrator:

```sql
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO <role>;
ALTER SCHEMA public OWNER TO <role>;
```

Do not set `LC_COLLATE` or `LC_CTYPE` generically.

Only set explicit collation when the repository documentation or an existing verified deployment requires it.

Do not expose PostgreSQL administrator credentials to applications.

---

# PostgreSQL Extensions

Most extensions cannot be created by a `NOSUPERUSER` application role.

The provisioner must:

1. Read required extensions from the verified application research.
2. Connect as PostgreSQL administrator.
3. Run `CREATE EXTENSION IF NOT EXISTS <extension>` in the application's database.
4. Verify the extension exists.
5. Return control to the application role.

Before selecting a shared PostgreSQL image, verify that it contains every required extension binary.

The stock `postgres:16` image does not automatically provide all common extensions such as:

- pgvector,
- PostGIS,
- TimescaleDB.

When the shared image lacks a required extension:

- select a compatible shared image when this is safe for every application, or
- classify the application as Class D and give it dedicated PostgreSQL.

Do not claim extension support merely because SQL syntax exists.

---

# PostgreSQL Connection Budget

Calculate:

```text
sum(
  expected application connections
  + workers
  + schedulers
  + migration jobs
  + monitoring
)
+ administrator headroom of at least 10
<= max_connections
```

Record the arithmetic in:

```text
docs/DATABASE_AND_CACHE_ALLOCATIONS.md
```

Set:

- explicit PostgreSQL `max_connections`,
- per-role `CONNECTION LIMIT`.

Do not guess connection counts silently.

When exact figures are unavailable:

- mark them `UNVERIFIED`,
- estimate conservatively,
- explain the estimate,
- validate through observed connection usage after deployment.

Add PgBouncer in transaction mode only when:

- the calculated total exceeds the safe direct-connection budget, or
- observed usage approaches the limit.

Before using transaction pooling, identify applications incompatible with it, including applications relying on:

- prepared statements that require session persistence,
- `LISTEN/NOTIFY`,
- session-level advisory locks,
- temporary tables across statements,
- session variables or session state.

Document exceptions.

---

# PostgreSQL Provisioning

Docker `/docker-entrypoint-initdb.d` scripts run only when the data directory is empty.

They are not the provisioning mechanism.

All role, database, schema, and extension creation must happen through the idempotent provisioning tool against the running PostgreSQL server.

The tool must support applications added months later without reinitialising the cluster.

---

# Valkey Cache

Use for:

- cache,
- disposable sessions where acceptable,
- rate limiting,
- short-lived locks,
- temporary state.

Configuration:

```text
Persistence: disabled by default
Eviction: allkeys-lru unless verified otherwise
Memory limit: explicit
Protected mode: enabled
Authentication: enabled
```

---

# Valkey Queues

Use for:

- BullMQ,
- Laravel queues,
- delayed jobs,
- workflow state,
- retry queues,
- other durable job processing.

Configuration:

```text
Persistence: AOF enabled
appendfsync: everysec
Eviction: noeviction
Persistent volume: required
Memory limit: explicit
Authentication: enabled
```

---

# Valkey Isolation

Logical database numbers are not security boundaries.

A client with the shared password may be able to:

- select another database,
- read unrelated keys,
- publish or subscribe to unrelated channels,
- execute `FLUSHDB`,
- execute `FLUSHALL`,
- alter server-wide configuration if permitted.

Use this preference order:

```text
1. Shared Valkey with a separate ACL user per application.
2. Restrict each user to application key prefixes and Pub/Sub channel prefixes.
3. Deny destructive and administrative commands.
4. Use application key prefixes.
5. Use logical DB numbers only as organisation, not security.
6. Give the application a dedicated Valkey instance when ACLs or prefixes are unsupported.
```

At minimum, deny where compatible:

```text
FLUSHALL
FLUSHDB
CONFIG
ACL
SHUTDOWN
DEBUG
MODULE
```

Verify from source that each application:

1. supports a Valkey username and password, or document that it does not,
2. supports a key prefix or configurable DB index,
3. does not call `FLUSHALL` or `FLUSHDB`,
4. does not require conflicting global keyspace-notification settings,
5. does not assume unrestricted administrative commands.

Record file paths and line references in the application research.

When any requirement fails, classify the application as Class D for Valkey and deploy a dedicated instance.

Where supported, prefer prefixes because:

- Valkey Cluster supports only database 0,
- many managed Redis-compatible systems support only database 0,
- prefixes are more portable than logical DB numbers.

---

# Allocation Registry

Record non-secret allocations in `catalog/allocations.yaml`:

```yaml
shared_infrastructure:
  postgres:
    resource_uuid: <uuid>
    hostname: <discovered-hostname>
  valkey_cache:
    resource_uuid: <uuid>
    hostname: <discovered-hostname>
  valkey_queue:
    resource_uuid: <uuid>
    hostname: <discovered-hostname>

applications:
  plane:
    environment: production
    postgres:
      database: ogg_plane_prod
      role: ogg_plane_prod
      connection_limit: 20
      extensions: [pgcrypto]
    valkey:
      cache_instance: valkey-cache
      cache_db: 1
      cache_prefix: "plane:"
      cache_acl_user: plane-prod
      queue_instance: valkey-queue
      queue_db: 1
      queue_prefix: "plane:q:"
      queue_acl_user: plane-prod
    coolify:
      resource_uuid: <uuid>
    storage:
      bucket: ogg-plane-prod
```

Never store passwords or tokens in this file.

---

# Dedicated Infrastructure Classification

Give an application dedicated infrastructure when it:

- requires another database engine,
- requires a conflicting PostgreSQL version,
- requires runtime superuser privileges,
- requires an extension unavailable in the shared PostgreSQL image,
- cannot use a Valkey ACL username,
- cannot use a key prefix or DB index safely,
- calls `FLUSHALL` or `FLUSHDB`,
- has conflicting global Valkey configuration requirements,
- has unpredictable resource consumption,
- requires strict regulatory or security isolation,
- creates an unacceptable shared failure domain.

Document the exact evidence and cost.

---

# Coolify Networking

Two facts drive the networking model:

1. Each Compose stack normally has its own Docker network.
2. Cross-stack communication requires **Connect to Predefined Network**.

Rules:

- deploy communicating resources to the same Coolify server and destination,
- enable **Connect to Predefined Network** for shared infrastructure,
- enable it for every application using shared infrastructure,
- do not add custom Compose `networks:` blocks unless strictly required and tested,
- do not expose PostgreSQL or Valkey publicly,
- assign domains only to web-facing services.

## Hostname discovery

Do not guess cross-stack hostnames.

After deploying shared infrastructure:

1. read the actual internal connection URL or service/container name from Coolify,
2. when necessary, inspect `docker ps` on the server,
3. verify DNS resolution from inside a connected application container,
4. record the authoritative hostname in `catalog/allocations.yaml`,
5. inject it into applications as:
   - `SHARED_POSTGRES_HOST`,
   - `SHARED_VALKEY_CACHE_HOST`,
   - `SHARED_VALKEY_QUEUE_HOST`.

Do not set `container_name` on shared services.

Let Coolify control resource naming.

Explicit `container_name` values can:

- create collisions,
- interfere with previews,
- interfere with replacement deployments,
- break Coolify's naming expectations.

The discovered Coolify-generated hostname is authoritative.

---

# Coolify Magic Environment Variables

Where supported, Coolify can generate:

- domains,
- URLs,
- passwords,
- Base64 secrets,
- random strings.

Examples include:

```text
SERVICE_FQDN_<NAME>
SERVICE_URL_<NAME>
SERVICE_PASSWORD_<NAME>
SERVICE_PASSWORD_64_<NAME>
SERVICE_BASE64_<NAME>
SERVICE_REALBASE64_<NAME>
```

Use them only after confirming the live Coolify version supports them for the selected deployment mode.

Use Coolify generation for:

- FQDNs,
- URLs,
- secrets used only inside one stack,
- internal application signing keys where no external provisioning step needs the value.

Use the provisioner for values that must also be applied to another system, including:

- PostgreSQL role passwords,
- Valkey ACL passwords,
- object-storage credentials created outside the stack.

Document the split in `docs/COOLIFY_SETUP.md`.

Do not rely on magic variables when the version is unsupported or unknown.

---

# Repository Investigation

For each repository, inspect and record evidence for:

- README and documentation,
- Dockerfiles,
- Compose files,
- package manifests and lockfiles,
- `.env.example`,
- entrypoints,
- startup commands,
- migration commands,
- worker commands,
- scheduler commands,
- health endpoints,
- database engine and version,
- required extensions,
- connection-pool settings,
- Valkey use,
- Valkey usernames,
- DB indexes,
- key prefixes,
- `FLUSHALL`,
- `FLUSHDB`,
- keyspace notifications,
- Pub/Sub,
- streams,
- object storage,
- persistent paths,
- expected container UID/GID,
- official images,
- release tags,
- digests,
- CPU architectures,
- licence restrictions,
- expected CPU and memory footprint,
- expected connection count.

Write findings to:

```text
docs/research/<slug>.md
```

Include file paths, line ranges, commit IDs, and direct evidence.

Then summarise into `docs/APPLICATION_MATRIX.md`.

Required matrix fields:

| Field | Required content |
|---|---|
| Repository | URL and inspected commit |
| Ownership | First-party or third-party |
| Licence | Licence implications |
| Runtime | Node, PHP, Python, Go, etc. |
| Existing image | Registry, tags, digest, architectures |
| Dockerfile | Location and quality |
| Compose | Existing services |
| Public ports | Web, API, WebSocket |
| Database | Engine, version, extensions |
| Valkey | Cache, queue, sessions, streams, prefix support, ACL support, FLUSH usage |
| Object storage | S3, MinIO, filesystem |
| Workers | Exact verified commands |
| Scheduler | Exact verified commands |
| Migrations | Exact verified command and rerun safety |
| Volumes | Paths, purpose, container UID |
| Health check | Endpoint or command and measured start time |
| Resource footprint | Verified value or `UNVERIFIED` estimate |
| Connections | Expected PostgreSQL connections |
| Shared-infra compatibility | Yes, no, conditional, with evidence |
| Deployment class | A, B, C, or D |
| Risks | Upgrade and operational risks |
| Evidence | Path to research file |

Do not remove bundled dependencies before confirming external equivalents are supported.

---

# Application Deployment Classes

## Class A: First-party repository

For applications I control:

1. add or improve a production Dockerfile,
2. run linting and tests,
3. build the image in GitHub Actions,
4. push to GHCR,
5. tag with:
   - `main`,
   - `sha-<commit>`,
6. update Coolify `IMAGE_TAG` to the immutable SHA tag,
7. trigger Coolify,
8. poll deployment status,
9. verify migrations,
10. run smoke tests.

Flow:

```text
Commit to main
    ↓
Required checks pass
    ↓
Build for server architecture
    ↓
Push main and sha-<commit>
    ↓
Set Coolify IMAGE_TAG=sha-<commit>
    ↓
Trigger deployment
    ↓
Verify migration exit status
    ↓
Verify application health
    ↓
Run smoke tests
```

Compose pattern:

```yaml
services:
  app:
    image: ghcr.io/<org>/<app>:${IMAGE_TAG:-main}
```

### Rollback

`IMAGE_TAG` lives in Coolify.

Rollback procedure:

1. identify a previous known-good immutable `sha-*` tag,
2. review the migration compatibility note in `docs/RUNBOOKS.md`,
3. set `IMAGE_TAG` to the previous tag,
4. redeploy,
5. inspect migration state,
6. run smoke tests.

This rolls back code only.

If the failed release applied an irreversible or incompatible migration:

- do not blindly roll back the image,
- follow the application's migration recovery runbook,
- restore from backup when necessary.

---

## Class B: Third-party with official image

- use the official image,
- pin a release tag,
- record the image digest in `VERSION`,
- keep Compose customisation in `coolify-deployments`,
- configure Dependabot or Renovate,
- review release notes and migration notes,
- update through pull requests,
- never auto-deploy an unreviewed upstream release.

---

## Class C: Third-party without official image

- use a minimal build repository or maintained fork,
- pin upstream tag or commit,
- isolate patches,
- ensure patches are reproducible,
- build for the server architecture,
- publish to GHCR,
- document all deviations and the patch-rebase procedure.

---

## Class D: Dedicated infrastructure required

Keep the application's required database, Valkey, or storage service in its own stack.

Document:

- the verified requirement,
- why sharing is unsafe or impossible,
- additional resource cost,
- dedicated backup arrangement,
- upgrade procedure,
- recovery procedure.

---

# Application Compose Files

For every application create:

```text
applications/<slug>/
├── compose.yaml
├── .env.example
├── .env.validate
├── README.md
├── VERSION
└── scripts/
```

Requirements:

- pinned third-party image or configurable first-party `IMAGE_TAG`,
- no secret defaults,
- `${VARIABLE:?}` for required variables,
- no custom network unless verified and justified,
- no public database or Valkey ports,
- verified health checks,
- realistic `start_period`,
- all required workers and schedulers,
- persistent volumes only when needed,
- correct UID/GID for writable volumes,
- migration service with:
  - `restart: "no"`,
  - `exclude_from_hc: true`,
- application and workers gated on migration completion where supported,
- `restart: unless-stopped` for long-running services,
- bounded logging configuration,
- no third-party `latest`,
- repeatable redeployment.

## Resource limits

Set `mem_limit` and `cpus` only when derived from:

- upstream documentation,
- an existing verified deployment,
- measured runtime behaviour,
- a clearly documented conservative estimate.

When no reliable value exists:

- write `UNVERIFIED`,
- deploy the representative application with monitored conservative limits where safe,
- measure steady-state and peak usage,
- update through a reviewed change.

Do not invent resource limits merely to satisfy the template.

## Generic pattern

```yaml
x-common: &common
  image: ${APP_IMAGE:?}:${IMAGE_TAG:-main}
  environment:
    DATABASE_URL: ${DATABASE_URL:?}
    REDIS_URL: ${REDIS_URL:?}
    QUEUE_URL: ${QUEUE_URL:?}
    APP_SECRET: ${APP_SECRET:?}
    TZ: ${TZ:-UTC}
  logging:
    driver: json-file
    options:
      max-size: "10m"
      max-file: "3"

services:
  migrate:
    <<: *common
    command: <verified-migration-command>
    restart: "no"
    exclude_from_hc: true

  app:
    <<: *common
    restart: unless-stopped
    depends_on:
      migrate:
        condition: service_completed_successfully
    healthcheck:
      test: <verified-health-command>
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: <measured-or-verified-value>

  worker:
    <<: *common
    restart: unless-stopped
    command: <verified-worker-command>
    depends_on:
      migrate:
        condition: service_completed_successfully
```

Do not copy this blindly.

Match the actual application.

---

# Worker Liveness

Every worker must have a verified liveness strategy.

Preference order:

1. application-provided worker health endpoint,
2. queue heartbeat or heartbeat key,
3. framework-supported worker-status command,
4. verified process check as a last resort.

If no reliable liveness command exists:

- mark worker liveness `PENDING`,
- monitor:
  - container exit status,
  - restart count,
  - queue depth,
  - oldest-job age,
  - heartbeat where one can be added safely.

Do not invent a worker-health command.

A process existing does not prove that the worker is connected to the queue or consuming jobs.

---

# Cross-Stack Startup Ordering

Compose `depends_on` cannot reference services in another stack.

An application may start before shared PostgreSQL or Valkey is ready.

Therefore the migration/startup path must use a bounded readiness check:

1. wait for TCP reachability,
2. verify PostgreSQL with `SELECT 1`,
3. verify Valkey with authenticated `PING`,
4. cap the wait, for example at 120 seconds,
5. exit non-zero on timeout,
6. do not swallow the failure and start the application anyway.

Use verified commands available in the image, or a small verified helper image/script.

---

# Migration Verification

A terminal Coolify deployment status does not prove migrations succeeded.

After deployment:

- inspect the migration container exit code,
- inspect migration logs,
- verify there is no migration failure,
- query the application's migration/version table where available,
- only then run public smoke tests.

For each application, record in `docs/RUNBOOKS.md`:

- whether migrations are reversible,
- whether the previous image can run against the new schema,
- whether migrations are transactional,
- whether a backup is required before deployment,
- recovery procedure for failed or partial migration.

---

# Provisioning Tool

Create an idempotent provisioning tool.

Preferred implementation:

- TypeScript where appropriate,
- otherwise Python 3,
- avoid a fragile set of undocumented shell scripts.

Commands:

```bash
./scripts/provision-application <slug> --environment production [--dry-run]
./scripts/deprovision-application <slug> --environment production
./scripts/rotate-secret <slug> --secret database-password --environment production
./scripts/validate-all
./scripts/smoke-test <slug>
```

## Mandatory dry run

`--dry-run` must:

- print every planned action,
- print redacted SQL,
- print redacted API requests,
- print allocation decisions,
- make no changes.

Test the redaction.

## Provisioning behaviour

`provision-application` must:

1. read `catalog/applications.yaml`,
2. validate slug and environment,
3. acquire a lock,
4. verify shared infrastructure is deployed and healthy,
5. resolve actual shared hostnames,
6. generate the PostgreSQL password,
7. create or verify the role and connection limit,
8. create or verify the database,
9. configure schema ownership,
10. enable required extensions as administrator,
11. allocate Valkey ACL user, prefixes, and DB index where supported,
12. otherwise identify the dedicated-instance requirement,
13. create object-storage bucket and scoped credentials where needed,
14. generate non-Coolify application secrets,
15. render a local gitignored file under `state/`,
16. create or update the Coolify resource,
17. set sensitive environment variables,
18. enable the predefined network,
19. configure the domain,
20. trigger deployment,
21. honour API rate limits,
22. poll deployment to terminal state,
23. verify migrations,
24. run smoke tests,
25. write non-secret allocations and UUIDs,
26. report created, already correct, skipped, and failed actions.

Every step must distinguish:

```text
CREATED
ALREADY_CORRECT
SKIPPED
EXISTS_BUT_DIFFERS
FAILED
```

On `EXISTS_BUT_DIFFERS`:

- stop,
- report the difference,
- do not silently reconcile destructive or security-sensitive differences.

On partial failure:

- list completed actions,
- give exact remediation,
- give rollback instructions,
- do not delete data automatically.

Never log:

- passwords,
- tokens,
- connection strings,
- OAuth secrets,
- SMTP credentials,
- full sensitive environment payloads.

---

# Deprovisioning

By default:

- stop or remove the Coolify resource,
- retain the database,
- retain roles unless explicitly requested,
- retain object storage,
- retain backups,
- retain allocation history.

Permanent data deletion requires:

```bash
--destroy-data --confirm <application-slug>
```

Before deletion:

1. create a final backup,
2. verify the backup exists,
3. restore-test it when required by policy,
4. list all affected resources,
5. require exact confirmation.

---

# Secret Rotation

`rotate-secret` must:

1. generate the new value,
2. apply it to the backing service,
3. update the sensitive Coolify environment variable,
4. redeploy,
5. verify application health,
6. verify dependent workers,
7. invalidate the old credential only after the new one works.

Where dual credentials are unsupported:

- document required downtime,
- stop the application safely,
- rotate,
- restart,
- verify.

Never rotate a production credential without explicit authorisation.

---

# Coolify API

Use the current Coolify API.

## Version and endpoint feature detection

Do not assume deprecated endpoints exist.

For Git-backed Docker Compose applications:

- use the applicable public or private Git repository application endpoint,
- set the build pack to Docker Compose,
- set the explicit Compose-file path.

For raw Compose service creation:

- use the current services endpoint.

Do not rely on the removed/deprecated Docker Compose application endpoint on current Coolify versions.

Feature-detect endpoint availability when supporting older installations.

## Required API capabilities

Use the API to:

- create Git-backed Compose applications,
- create raw Compose services where appropriate,
- create resources from public repositories,
- create resources from private repositories through the Coolify GitHub App,
- set environment variables,
- mark secrets sensitive,
- set project, environment, server, and destination,
- enable connection to the predefined network,
- configure domains,
- set `IMAGE_TAG`,
- trigger deployment,
- poll deployment status,
- read logs when available,
- record resource UUIDs.

## API deployment behaviour

Deployment trigger:

```bash
curl --fail --silent --show-error \
  --request GET \
  "${COOLIFY_URL}/api/v1/deploy?uuid=${COOLIFY_RESOURCE_UUID}&force=false" \
  --header "Authorization: Bearer ${COOLIFY_TOKEN}"
```

A successful trigger response does not mean deployment succeeded.

Poll until a terminal status.

When Coolify returns HTTP `429`:

- read `Retry-After`,
- wait,
- retry with bounded backoff,
- do not retry immediately in a tight loop.

Use least-privilege API tokens.

Never print tokens.

Some placement fields may be immutable after resource creation, including:

- project,
- environment,
- server,
- destination,
- build pack.

Validate them before creation.

## When API access is absent

Create exact UI instructions in `docs/MANUAL_ACTIONS.md`:

1. repository,
2. branch,
3. Docker Compose build pack,
4. base directory,
5. explicit Compose-file path,
6. required environment variables,
7. which variables are sensitive,
8. domain,
9. Connect to Predefined Network,
10. deployment order,
11. health verification,
12. deployment trigger configuration.

---

# Automatic Deployment from `main`

Automatic deployment is allowed only when `main` is protected and required checks are active.

## Define tested

Required before unattended production deployment:

- pull-request workflow,
- required lint check,
- required test check,
- no direct pushes to `main`,
- branch protection confirmed active.

A pull request can add CI workflows but cannot itself enable branch protection.

The agent must:

1. inspect branch-protection state through the GitHub API when authorised,
2. configure branch protection through the API or repository settings when authorised,
3. otherwise add the exact settings to `docs/MANUAL_ACTIONS.md`,
4. treat unattended auto-deploy as unsafe until protection is confirmed.

## GitHub Actions workflow

For first-party repositories:

1. trigger on pushes to `main`,
2. allow `workflow_dispatch`,
3. accept an optional known-good image tag for manual redeploy,
4. run lint and tests,
5. build for the verified server architecture,
6. log in to GHCR,
7. push:
   - `main`,
   - `sha-<commit>`,
8. update Coolify `IMAGE_TAG` to `sha-<commit>`,
9. trigger deployment,
10. poll deployment status,
11. inspect migration result,
12. run smoke tests,
13. fail when deployment or smoke tests fail.

Required secrets:

```text
COOLIFY_URL
COOLIFY_TOKEN
COOLIFY_RESOURCE_UUID
```

Workflow requirements:

```text
permissions:
  contents: read
  packages: write
```

Use:

- `docker/setup-buildx-action`,
- `docker/setup-qemu-action` only when cross-building,
- `docker/login-action`,
- `docker/metadata-action`,
- `docker/build-push-action`,
- registry or GitHub Actions cache,
- immutable SHA tags,
- per-application concurrency,
- `cancel-in-progress: false` for deployment jobs,
- `set -euo pipefail` in shell steps,
- no secret output.

Do not enable both:

- Coolify GitHub App auto-deploy,
- GitHub Actions deployment,

for the same application.

Verify the Coolify auto-deploy toggle is disabled before shipping the Actions workflow.

For third-party software:

- updates are pull-request driven,
- reviewed manually,
- never deployed automatically from upstream.

---

# Source Repository Changes

For first-party repositories, prepare focused pull requests adding missing components:

```text
Dockerfile
.dockerignore
.github/workflows/ci.yml
.github/workflows/build-and-deploy.yml
health endpoint or health command
production startup command
migration command
worker command
deployment documentation
```

Do not push directly to `main` unless explicitly authorised.

For third-party applications without an image:

- use a minimal fork or build repository,
- configure upstream remote,
- isolate patches,
- document update and rebase procedures.

---

# Secrets and Environment Variables

Create `.env.example` files containing names and safe descriptions only.

Create `.env.validate` files with non-secret dummy values sufficient for:

```bash
docker compose config
```

Rules:

- unique database password per application per environment,
- unique application encryption secrets,
- no generated `.env` committed,
- no administrator credentials in application containers,
- URL-encode passwords in connection strings,
- do not put secrets in build arguments,
- use BuildKit secrets only when a build genuinely requires a secret,
- never log full connection strings,
- mark secrets sensitive in Coolify,
- do not publish database or Valkey ports.

Document rotation procedures and downtime requirements in `docs/SECURITY.md`.

---

# Health Checks and Smoke Tests

Every public application must have a meaningful verified health check.

Priority:

1. official health endpoint,
2. lightweight API endpoint,
3. process-specific command,
4. TCP as a last resort.

Set `start_period` from:

- upstream documentation,
- measured cold start,
- verified existing deployment.

Do not guess it silently.

Smoke tests must verify:

- public domain responds,
- expected HTTP status,
- TLS certificate is valid and covers the domain,
- expected version or commit is running where observable,
- database connectivity,
- queue worker consumes a test job,
- required background services run,
- object storage works when required,
- internal ports are not reachable from outside the server,
- one application cannot access another application's PostgreSQL database using its own credentials.

The cross-database isolation test must expect failure.

Do not perform destructive production operations during smoke tests.

---

# Backups

## PostgreSQL

Configure:

- scheduled off-server backups,
- Coolify-managed backups when using a Coolify-managed database resource,
- custom scheduled backups when PostgreSQL runs in Compose,
- daily per-database logical backups where practical,
- explicit retention,
- backup-failure monitoring,
- a restore test,
- full-cluster recovery documentation,
- single-application restore into a temporary database,
- measured restore time for the largest database.

A backup test must verify:

- off-server object exists,
- file size is plausible,
- restore command succeeds,
- restored data can be queried.

Do not restore over the live database during testing.

## Valkey

Cache:

- no backup required unless non-disposable data is found.

Queues:

- AOF enabled,
- persistent volume,
- document possible loss since last fsync,
- document queue recovery,
- document replay behaviour.

Valkey persistence does not replace durable application state.

## Object storage

For each application:

- separate bucket or restricted prefix,
- application-specific credentials,
- lifecycle policy,
- retention policy,
- export procedure,
- restore procedure.

Back up self-hosted MinIO outside the Coolify server.

---

# Security

- keep PostgreSQL and Valkey internal,
- use one database and role per application per environment,
- do not grant application superuser access,
- revoke public database access,
- use separate application secrets,
- use separate Valkey ACL users where supported,
- deny destructive Valkey commands,
- use least-privilege object-storage access,
- pin third-party tags and digests,
- avoid Docker socket mounts,
- avoid privileged containers,
- avoid host networking,
- avoid broad bind mounts,
- run containers as non-root where supported,
- use immutable SHA image tags,
- use expiring least-privilege API tokens,
- treat deployment tokens as secrets,
- verify firewall exposure from outside the server,
- back up Coolify itself.

Create `docs/SECURITY.md` explaining the shared-network blast radius.

State clearly:

- compromising one application container gives the attacker network access to shared services,
- PostgreSQL isolation depends on per-application credentials, database ownership, and revoked public access,
- Valkey logical DB numbers do not protect applications from one another,
- Valkey ACLs and dedicated instances are the meaningful isolation mechanisms.

---

# Validation

## Static validation

Run:

```bash
docker compose --env-file .env.validate config
```

for every stack.

Verify:

- no committed secrets,
- secret scan passes,
- no third-party `latest`,
- no duplicate host ports,
- no public PostgreSQL or Valkey ports,
- no conflicting custom networks,
- stateful services have storage,
- long-running services have restart policies,
- resource limits are verified or marked `UNVERIFIED`,
- public apps have health checks,
- workers have verified liveness or are marked `PENDING`,
- migration services use `restart: "no"` and are excluded from health,
- database names are unique,
- role names are unique,
- Valkey ACL users and prefixes are unique,
- allocation catalog matches deployed state.

## Live validation

Verify:

- shared infrastructure deploys first,
- PostgreSQL is healthy,
- connection budget fits,
- both Valkey instances are healthy,
- shared hostnames resolve inside application containers,
- provisioning is idempotent,
- migrations succeed,
- migration container exits successfully,
- workers consume a test job,
- domains resolve,
- TLS is valid,
- application survives redeploy,
- application survives container restart,
- server reboot recovery is tested in Milestone 2,
- successful commit to `main` triggers exactly one deployment,
- deliberately failing tests trigger no deployment,
- rollback to previous SHA works,
- one application cannot connect to another application's database.

## Backup validation

Verify:

- scheduled job runs,
- off-server object exists,
- restore into temporary database succeeds,
- restored data is queryable,
- restore duration is recorded,
- documentation matches the tested commands.

Mark unavailable tests `PENDING`.

Include the reason for each pending item.

---

# Definition of Done

## Milestone 1 is complete when:

1. Every repository has a research file and deployment class.
2. The application matrix exists.
3. Shared infrastructure is deployed and healthy.
4. Actual internal hostnames are recorded.
5. At least one representative first-party application is deployed end to end.
6. The representative application has:
   - migrations,
   - worker,
   - web endpoint,
   - domain,
   - TLS,
   - passing smoke test.
7. Provisioning has been run twice with no unintended second-run changes.
8. First-party CI builds immutable GHCR images.
9. A successful commit deploys exactly once.
10. A failing test deploys zero times.
11. A basic off-server backup exists.
12. All deferred hardening is recorded.

## Milestone 2 is complete when:

1. Valkey ACL isolation is implemented where supported.
2. Connection budgets are verified.
3. PgBouncer is added where justified.
4. Secret rotation is tested.
5. Rollback is tested.
6. Database restore is tested.
7. Full-server reboot recovery is tested.
8. Cross-database isolation is tested.
9. Worker monitoring exists.
10. Branch protection is active.
11. Coolify disaster recovery is documented and tested.
12. Required runbooks are complete.

The full project is complete only when both milestones are complete.

---

# Required Documentation

Create:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/APPLICATION_MATRIX.md`
- `docs/DATABASE_AND_CACHE_ALLOCATIONS.md`
- `docs/COOLIFY_SETUP.md`
- `docs/CI_CD.md`
- `docs/BACKUP_AND_RESTORE.md`
- `docs/OPERATIONS.md`
- `docs/RUNBOOKS.md`
- `docs/SECURITY.md`
- `docs/MANUAL_ACTIONS.md`

`docs/RUNBOOKS.md` must cover:

- shared PostgreSQL down,
- shared Valkey cache down,
- shared Valkey queue down,
- one application failing deployment,
- failed migration,
- incompatible rollback,
- leaked credential,
- disk full,
- backup failure,
- restoring one application's database,
- Coolify server loss.

`docs/MANUAL_ACTIONS.md` must include:

- exact screen or repository,
- exact variable or secret,
- expected format,
- why it is required,
- how to verify completion.

---

# Git Behaviour

- work in branches,
- make logical commits,
- commit research after each repository,
- do not commit secrets,
- do not rewrite upstream history,
- create focused pull requests,
- include command output and test evidence,
- state assumptions,
- list files changed,
- state live tests completed,
- list pending items,
- do not merge without authorisation.

---

# Execution Order

1. Confirm access:
   - Coolify version,
   - API reachability,
   - GitHub permissions,
   - server architecture,
   - wildcard DNS.
2. Inspect repositories one at a time.
3. Commit each repository research file.
4. Classify each repository.
5. Produce the application matrix.
6. Design shared infrastructure.
7. Decide PostgreSQL deployment mechanism.
8. Calculate initial connection budget.
9. Create the deployment repository.
10. Deploy shared infrastructure.
11. Discover and record actual hostnames.
12. Build the idempotent provisioner.
13. Prove `--dry-run`.
14. Select one representative Class A application with:
    - migrations,
    - worker,
    - web endpoint.
15. Implement the representative application end to end.
16. Validate automatic deployment from `main`.
17. Validate the negative CI case.
18. Complete Milestone 1.
19. Apply the pattern to remaining applications.
20. Configure and test backups.
21. Complete Milestone 2 hardening.
22. Run full validation.
23. Produce the final report.

Do not build every template before proving the pattern on the representative application.

---

# Required Final Report

## Executive summary

Explain:

- the architecture created,
- what is operational,
- what remains pending,
- the three things most likely to break.

## Repository classification

For every repository:

```text
Repository
Ownership
Inspected ref
Deployment class
Image strategy
Database strategy
Valkey strategy
Storage strategy
Automatic deployment strategy
Exceptions
Risks
Evidence file
```

## Files and pull requests

Provide links or paths.

## Infrastructure

List:

- shared services,
- actual internal hostnames,
- PostgreSQL deployment option,
- databases,
- roles,
- connection limits,
- extensions,
- Valkey allocations,
- ACL users and prefixes,
- object-storage buckets,
- Coolify resource UUIDs,
- domains,
- deployment triggers.

Never reveal passwords.

## Validation evidence

For every test:

```text
Test
Status: PASSED | FAILED | PENDING
Command
Evidence path
Reason when PENDING
```

## Manual actions

List exact unresolved steps.

## Known risks

Include:

- shared PostgreSQL blast radius,
- PostgreSQL connection exhaustion,
- shared Valkey blast radius,
- Valkey logical DBs not being security boundaries,
- upstream maintenance burden,
- migration risk,
- code rollback versus schema rollback,
- backup gaps,
- untested restores,
- applications requiring dedicated infrastructure,
- single-server failure risk,
- Coolify control-plane recovery risk.

---

# Final Constraint

Do not over-engineer this into Kubernetes, Terraform, Kafka, or a custom platform unless a repository proves it is required.

The intended result is:

```text
Git repository list
        ↓
Repository inspection with committed evidence
        ↓
Shared PostgreSQL + shared Valkey where safe
        ↓
One database and credential set per application per environment
        ↓
Coolify-ready Compose definitions
        ↓
Idempotent provisioning
        ↓
First-party GHCR image builds
        ↓
Automatic tested deployment from main
        ↓
Verified backup, rollback, isolation, and operations
```
