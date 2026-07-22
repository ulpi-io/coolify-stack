# Plan: Phase 2: Sixteen Platform Folders

## Overview

All 16 platform Compose and environment-generator pairs pass folder-scoped validation.

## Scope Challenge

- Mode: EXPANSION
- Default review: codex
- Delivery: compose artifacts only
- Environment: production only
- Decision: The scope is the complete stack, not a deployment system: 17 Compose files, 17 environment generators, one static validator, and Coolify handoff documentation.

## Prerequisites

- REPOSITORIES.md remains the authoritative 16-platform/domain inventory.
- SHARED_INFRASTRUCTURE.md remains the authoritative shared-service, consumer, database-engine, and isolation map.
- The implementation agent must inspect the pinned repository or recipe evidence before writing each platform process command or image reference.
- Docker Compose v2, shellcheck, openssl, and standard POSIX tools are available for local validation.

## Non-Goals

- No Coolify API calls, UI automation, server mutation, DNS change, resource creation, or deployment execution.
- No custom Python deployment control plane, provider framework, CI rollout system, branch-protection work, or repository source PRs.
- No application-data migration, legacy-volume reuse, database-engine conversion, or production cutover.
- No staging environment and no duplicate shared backing services inside platform Compose files.

## Contracts

- Folder contract: infrastructure/compose.yaml plus infrastructure/generate-env.sh, and platforms/<slug>/compose.yaml plus platforms/<slug>/generate-env.sh for all 16 slugs.
- The infrastructure generator creates shared service credentials and matching per-platform shared-env fragments; each platform generator consumes only its own fragment and produces its local .env.
- Every generator refuses overwrite without --force, creates mode-0600 files, uses cryptographic randomness, prints no secrets, and is safe to rerun.
- Platform Compose files use the Coolify external shared network and environment-provided shared endpoints; depends_on is limited to services in the same file.
- All images are immutable or exactly versioned, all application services have health checks where supported, all required variables fail closed, and no shared backing port is publicly published.

## Existing Code Leverage

- REPOSITORIES.md supplies all platform names, component groupings, and domains.
- SHARED_INFRASTRUCTURE.md supplies all shared-service consumers and isolation decisions.
- N8N_CURRENT_RECIPE.md and TWENTY_CURRENT_RECIPE.md supply their complete current multi-process Compose baselines.
- Immutable source-tree evidence already captured for the first-party and third-party repositories supplies real Dockerfiles, commands, health routes, and environment names.

## Shared Infrastructure Map

Coolify deploys these artifacts later but is not part of the Compose stack.

| Component | Responsibility |
| --- | --- |
| Coolify and Traefik | External deployment, private networking, domains, and TLS; untouched by this implementation plan. |
| MySQL 8.4 LTS | Fresh databases and users for MySQL platforms |
| PostgreSQL 16 | Fresh databases and roles for PostgreSQL platforms and Temporal persistence |
| Valkey 8 cache | Disposable caches, sessions, limits, and locks |
| Valkey 8 queue | Durable Redis-compatible queues with AOF everysec and noeviction |
| MinIO | Shared bucket-isolated object storage |
| Qdrant | Shared collection-isolated vector storage |
| RabbitMQ | Shared vhost-isolated AMQP messaging |
| Elasticsearch | Shared index/role-isolated search and Temporal visibility |
| Temporal | Shared namespace/task-queue-isolated durable workflows |
| Mailpit | Private capture-only SMTP with no relay |
| Monitoring | A pinned resource-bounded monitoring and alerting implementation selected in the Compose task |
| Backup | A pinned off-server backup implementation selected in the Compose task |

## Architecture and Data Flow

```mermaid
flowchart LR
      Infra[infrastructure/ compose plus generator] --> Network[Coolify external shared network]
      Network --> P1[platforms/kensi-ai]
      Network --> P2[platforms/agentshq]
      Network --> PN[14 other platform folders]
      Generator[Infrastructure generated shared fragments] --> G1[Each platform generate-env]
      G1 --> P1
      G1 --> P2
      G1 --> PN
      Infra --> Validate[Local validate-all]
      P1 --> Validate
      P2 --> Validate
      PN --> Validate
      Validate --> Docs[Manual Coolify import handoff]
```

| Component | Tasks |
| --- | --- |
| sixteen-platform-folders | TASK-002, TASK-003, TASK-004, TASK-005, TASK-006, TASK-007, TASK-008, TASK-009, TASK-010, TASK-011, TASK-012, TASK-013, TASK-014, TASK-015, TASK-016, TASK-017 |

## Tasks

### TASK-002: Create the Kensi AI platform stack

Create one production Compose file for Kensi AI, combining ulpi-io/kensi-ai-api and ulpi-io/kensi-ai-web into one logical Coolify platform stack. It contains API, web, worker, and scheduler and connects to MySQL 8.4, cache Valkey, queue Valkey, optional MinIO, and Mailpit when SMTP variables are present through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/kensi-ai/compose.yaml contains the verified API, web, worker, and scheduler, uses immutable image variables or exact image versions, targets https://kensi.ai, and references only the required shared endpoints: MySQL 8.4, cache Valkey, queue Valkey, optional MinIO, and Mailpit when SMTP variables are present.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/kensi-ai/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching kensi-ai shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/kensi-ai/compose.yaml`
- `platforms/kensi-ai/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/kensi-ai/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/kensi-ai/generate-env.sh --shared-env "$tmp_dir/platforms/kensi-ai.shared.env" --output "$tmp_dir/kensi-ai.env" && docker compose --env-file "$tmp_dir/kensi-ai.env" -f platforms/kensi-ai/compose.yaml config >/dev/null
```

### TASK-003: Create the AgentsHQ platform stack

Create one production Compose file for AgentsHQ, combining ulpi-io/agentshq-api and ulpi-io/agentshq-web into one logical Coolify platform stack. It contains API and web and connects to MySQL 8.4 through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/agentshq/compose.yaml contains the verified API and web, uses immutable image variables or exact image versions, targets https://www.agentshq.sh/, and references only the required shared endpoints: MySQL 8.4.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/agentshq/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching agentshq shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/agentshq/compose.yaml`
- `platforms/agentshq/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/agentshq/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/agentshq/generate-env.sh --shared-env "$tmp_dir/platforms/agentshq.shared.env" --output "$tmp_dir/agentshq.env" && docker compose --env-file "$tmp_dir/agentshq.env" -f platforms/agentshq/compose.yaml config >/dev/null
```

### TASK-004: Create the OpenKudos / TeamToast platform stack

Create one production Compose file for OpenKudos / TeamToast, combining ulpi-io/open-kudos-api and ulpi-io/open-kudos-web into one logical Coolify platform stack. It contains API, web, worker, and scheduler and connects to MySQL 8.4, cache Valkey, queue Valkey, and Mailpit whenever its mail variables are enabled through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/open-kudos/compose.yaml contains the verified API, web, worker, and scheduler, uses immutable image variables or exact image versions, targets https://www.teamtoast.ai/, and references only the required shared endpoints: MySQL 8.4, cache Valkey, queue Valkey, and Mailpit whenever its mail variables are enabled.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/open-kudos/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching open-kudos shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/open-kudos/compose.yaml`
- `platforms/open-kudos/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/open-kudos/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/open-kudos/generate-env.sh --shared-env "$tmp_dir/platforms/open-kudos.shared.env" --output "$tmp_dir/open-kudos.env" && docker compose --env-file "$tmp_dir/open-kudos.env" -f platforms/open-kudos/compose.yaml config >/dev/null
```

### TASK-005: Create the Insight / Clavinci platform stack

Create one production Compose file for Insight / Clavinci, combining ulpi-io/insight into one logical Coolify platform stack. It contains API and dashboard and connects to MySQL 8.4 through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/insight/compose.yaml contains the verified API and dashboard, uses immutable image variables or exact image versions, targets https://clavinci.com, and references only the required shared endpoints: MySQL 8.4.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/insight/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching insight shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/insight/compose.yaml`
- `platforms/insight/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/insight/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/insight/generate-env.sh --shared-env "$tmp_dir/platforms/insight.shared.env" --output "$tmp_dir/insight.env" && docker compose --env-file "$tmp_dir/insight.env" -f platforms/insight/compose.yaml config >/dev/null
```

### TASK-006: Create the Togglebox platform stack

Create one production Compose file for Togglebox, combining ulpi-io/togglebox into one logical Coolify platform stack. It contains MySQL-compatible API and admin and connects to MySQL 8.4; DynamoDB is forbidden through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/togglebox/compose.yaml contains the verified MySQL-compatible API and admin, uses immutable image variables or exact image versions, targets https://togglebox.dev, and references only the required shared endpoints: MySQL 8.4; DynamoDB is forbidden.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/togglebox/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching togglebox shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/togglebox/compose.yaml`
- `platforms/togglebox/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/togglebox/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/togglebox/generate-env.sh --shared-env "$tmp_dir/platforms/togglebox.shared.env" --output "$tmp_dir/togglebox.env" && docker compose --env-file "$tmp_dir/togglebox.env" -f platforms/togglebox/compose.yaml config >/dev/null
```

### TASK-007: Create the OpenPay platform stack

Create one production Compose file for OpenPay, combining CiprianSpiridon/OpenPayApi and CiprianSpiridon/OpenPayWeb into one logical Coolify platform stack. It contains API, web, worker/Horizon when enabled, and scheduler and connects to MySQL 8.4, database or Valkey-backed cache/queues as selected, optional MinIO, and Mailpit through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/openpay/compose.yaml contains the verified API, web, worker/Horizon when enabled, and scheduler, uses immutable image variables or exact image versions, targets https://www.openpay.fyi/, and references only the required shared endpoints: MySQL 8.4, database or Valkey-backed cache/queues as selected, optional MinIO, and Mailpit.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/openpay/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching openpay shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/openpay/compose.yaml`
- `platforms/openpay/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/openpay/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/openpay/generate-env.sh --shared-env "$tmp_dir/platforms/openpay.shared.env" --output "$tmp_dir/openpay.env" && docker compose --env-file "$tmp_dir/openpay.env" -f platforms/openpay/compose.yaml config >/dev/null
```

### TASK-008: Create the Ploon platform stack

Create one production Compose file for Ploon, combining ulpi-io/ploon-web into one logical Coolify platform stack. It contains stateless web and connects to No stateful shared dependency unless source evidence proves an API requirement through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/ploon/compose.yaml contains the verified stateless web, uses immutable image variables or exact image versions, targets https://ploon.ai, and references only the required shared endpoints: No stateful shared dependency unless source evidence proves an API requirement.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/ploon/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching ploon shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/ploon/compose.yaml`
- `platforms/ploon/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/ploon/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/ploon/generate-env.sh --shared-env "$tmp_dir/platforms/ploon.shared.env" --output "$tmp_dir/ploon.env" && docker compose --env-file "$tmp_dir/ploon.env" -f platforms/ploon/compose.yaml config >/dev/null
```

### TASK-009: Create the Open Growth Group website platform stack

Create one production Compose file for Open Growth Group website, combining CiprianSpiridon/open-growth-group-website into one logical Coolify platform stack. It contains stateless website and connects to No stateful shared dependency through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/open-growth-group/compose.yaml contains the verified stateless website, uses immutable image variables or exact image versions, targets https://opengrowthgroup.co, and references only the required shared endpoints: No stateful shared dependency.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/open-growth-group/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching open-growth-group shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/open-growth-group/compose.yaml`
- `platforms/open-growth-group/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/open-growth-group/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/open-growth-group/generate-env.sh --shared-env "$tmp_dir/platforms/open-growth-group.shared.env" --output "$tmp_dir/open-growth-group.env" && docker compose --env-file "$tmp_dir/open-growth-group.env" -f platforms/open-growth-group/compose.yaml config >/dev/null
```

### TASK-010: Create the Lokei platform stack

Create one production Compose file for Lokei, combining ulpi-io/lokei into one logical Coolify platform stack. It contains web/API, relay, Horizon worker, and scheduler and connects to MySQL 8.4, cache Valkey, and queue Valkey through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/lokei/compose.yaml contains the verified web/API, relay, Horizon worker, and scheduler, uses immutable image variables or exact image versions, targets https://lokei.dev, and references only the required shared endpoints: MySQL 8.4, cache Valkey, and queue Valkey.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/lokei/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching lokei shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/lokei/compose.yaml`
- `platforms/lokei/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/lokei/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/lokei/generate-env.sh --shared-env "$tmp_dir/platforms/lokei.shared.env" --output "$tmp_dir/lokei.env" && docker compose --env-file "$tmp_dir/lokei.env" -f platforms/lokei/compose.yaml config >/dev/null
```

### TASK-011: Create the Albert platform stack

Create one production Compose file for Albert, combining ulpi-io/albert into one logical Coolify platform stack. It contains API, web, Horizon worker, scheduler, and Reverb and connects to MySQL 8.4, cache Valkey, queue Valkey, and Qdrant through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/albert/compose.yaml contains the verified API, web, Horizon worker, scheduler, and Reverb, uses immutable image variables or exact image versions, targets https://albert.con.fyi, and references only the required shared endpoints: MySQL 8.4, cache Valkey, queue Valkey, and Qdrant.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/albert/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching albert shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/albert/compose.yaml`
- `platforms/albert/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/albert/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/albert/generate-env.sh --shared-env "$tmp_dir/platforms/albert.shared.env" --output "$tmp_dir/albert.env" && docker compose --env-file "$tmp_dir/albert.env" -f platforms/albert/compose.yaml config >/dev/null
```

### TASK-012: Create the Record Cloud platform stack

Create one production Compose file for Record Cloud, combining ulpi-io/record-cloud into one logical Coolify platform stack. It contains API and web and connects to MySQL 8.4, MinIO, and Mailpit through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/record-cloud/compose.yaml contains the verified API and web, uses immutable image variables or exact image versions, targets https://record.con.fyi, and references only the required shared endpoints: MySQL 8.4, MinIO, and Mailpit.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/record-cloud/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching record-cloud shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/record-cloud/compose.yaml`
- `platforms/record-cloud/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/record-cloud/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/record-cloud/generate-env.sh --shared-env "$tmp_dir/platforms/record-cloud.shared.env" --output "$tmp_dir/record-cloud.env" && docker compose --env-file "$tmp_dir/record-cloud.env" -f platforms/record-cloud/compose.yaml config >/dev/null
```

### TASK-013: Create the Plane platform stack

Create one production Compose file for Plane, combining makeplane/plane into one logical Coolify platform stack. It contains pinned Plane application services and connects to PostgreSQL 16, cache Valkey, RabbitMQ, and MinIO through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** L
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/plane/compose.yaml contains the verified pinned Plane application services, uses immutable image variables or exact image versions, targets https://pm.con.fyi, and references only the required shared endpoints: PostgreSQL 16, cache Valkey, RabbitMQ, and MinIO.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/plane/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching plane shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/plane/compose.yaml`
- `platforms/plane/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/plane/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/plane/generate-env.sh --shared-env "$tmp_dir/platforms/plane.shared.env" --output "$tmp_dir/plane.env" && docker compose --env-file "$tmp_dir/plane.env" -f platforms/plane/compose.yaml config >/dev/null
```

### TASK-014: Create the Postiz platform stack

Create one production Compose file for Postiz, combining ulpi-io/postiz-docker-compose into one logical Coolify platform stack. It contains pinned Postiz fork application services and connects to PostgreSQL 16, Valkey, Temporal, Elasticsearch, and its verified uploads storage contract through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** L
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/postiz/compose.yaml contains the verified pinned Postiz fork application services, uses immutable image variables or exact image versions, targets https://post.con.fyi, and references only the required shared endpoints: PostgreSQL 16, Valkey, Temporal, Elasticsearch, and its verified uploads storage contract.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/postiz/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching postiz shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/postiz/compose.yaml`
- `platforms/postiz/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/postiz/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/postiz/generate-env.sh --shared-env "$tmp_dir/platforms/postiz.shared.env" --output "$tmp_dir/postiz.env" && docker compose --env-file "$tmp_dir/postiz.env" -f platforms/postiz/compose.yaml config >/dev/null
```

### TASK-015: Create the Nudgra OSS platform stack

Create one production Compose file for Nudgra OSS, combining MaikoCode/nudgra-oss into one logical Coolify platform stack. It contains pinned Nudgra application services and connects to PostgreSQL 16 with pgcrypto and pg-boss through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** M
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/nudgra-oss/compose.yaml contains the verified pinned Nudgra application services, uses immutable image variables or exact image versions, targets https://ig.con.fyi, and references only the required shared endpoints: PostgreSQL 16 with pgcrypto and pg-boss.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/nudgra-oss/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching nudgra-oss shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/nudgra-oss/compose.yaml`
- `platforms/nudgra-oss/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/nudgra-oss/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/nudgra-oss/generate-env.sh --shared-env "$tmp_dir/platforms/nudgra-oss.shared.env" --output "$tmp_dir/nudgra-oss.env" && docker compose --env-file "$tmp_dir/nudgra-oss.env" -f platforms/nudgra-oss/compose.yaml config >/dev/null
```

### TASK-016: Create the n8n platform stack

Create one production Compose file for n8n, combining N8N_CURRENT_RECIPE.md into one logical Coolify platform stack. It contains n8n main, worker, and task runners using n8nio/n8n:2.10.4-compatible contracts and connects to PostgreSQL 16 and queue Valkey through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** L
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/n8n/compose.yaml contains the verified n8n main, worker, and task runners using n8nio/n8n:2.10.4-compatible contracts, uses immutable image variables or exact image versions, targets https://workflow.con.fyi, and references only the required shared endpoints: PostgreSQL 16 and queue Valkey.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/n8n/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching n8n shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/n8n/compose.yaml`
- `platforms/n8n/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/n8n/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/n8n/generate-env.sh --shared-env "$tmp_dir/platforms/n8n.shared.env" --output "$tmp_dir/n8n.env" && docker compose --env-file "$tmp_dir/n8n.env" -f platforms/n8n/compose.yaml config >/dev/null
```

### TASK-017: Create the Twenty platform stack

Create one production Compose file for Twenty, combining TWENTY_CURRENT_RECIPE.md into one logical Coolify platform stack. It contains Twenty app and worker using twentycrm/twenty:v1.15-compatible contracts and connects to PostgreSQL 16, cache Valkey, pg-boss, optional MinIO, and Mailpit through the shared external network without embedding duplicate backing services.

**Phase:** platform-stacks
**Type:** infra
**Effort:** L
**Agent:** devops-docker-senior-engineer
**Priority:** P1
**Review:** codex
**Depends on:** None
**External prerequisites:** TASK-001

**Acceptance Criteria:**

- platforms/twenty/compose.yaml contains the verified Twenty app and worker using twentycrm/twenty:v1.15-compatible contracts, uses immutable image variables or exact image versions, targets https://crm.con.fyi, and references only the required shared endpoints: PostgreSQL 16, cache Valkey, pg-boss, optional MinIO, and Mailpit.
- The Compose file declares the Coolify external shared network, contains no cross-stack depends_on entry, contains no duplicate MySQL/PostgreSQL/Valkey/MinIO/Qdrant/RabbitMQ/Elasticsearch/Temporal/Mailpit service, and fails configuration when a required variable is absent.
- platforms/twenty/generate-env.sh supports --shared-env <path> --output <path> [--force], validates the matching twenty shared fragment, writes a mode-0600 platform .env with generated application secrets and the canonical domain, prints no secrets, and refuses overwrite without --force.

**Write Scope:**

- `platforms/twenty/compose.yaml`
- `platforms/twenty/generate-env.sh`

**Validate Command:**

```bash
shellcheck platforms/twenty/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/twenty/generate-env.sh --shared-env "$tmp_dir/platforms/twenty.shared.env" --output "$tmp_dir/twenty.env" && docker compose --env-file "$tmp_dir/twenty.env" -f platforms/twenty/compose.yaml config >/dev/null
```

## Failure Modes

- Missing or conflicting source evidence blocks only the affected platform Compose task; it is never replaced by a guessed command or image.
- A generator missing its matching shared fragment, required input, openssl, or safe output permissions exits non-zero without creating a partial environment.
- An existing env file is preserved unless --force is explicit; secrets are never printed or committed.
- Any unresolved Compose variable, latest tag, public backing port, duplicate shared service, or cross-stack depends_on fails local validation.
- The repository never interprets successful static validation as a successful deployment.

## Ship Cut

- Milestone 1: The infrastructure folder and all 16 platform folders each contain a statically valid compose.yaml and generate-env.sh.
- Milestone 2: The 17-folder validator passes and the manual Coolify import guide covers every platform and domain without executing deployment.

## Test Coverage Map

| Task | Test type | Validate command |
| --- | --- | --- |
| TASK-002 | folder-scoped Compose and shell validation | `shellcheck platforms/kensi-ai/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/kensi-ai/generate-env.sh --shared-env "$tmp_dir/platforms/kensi-ai.shared.env" --output "$tmp_dir/kensi-ai.env" && docker compose --env-file "$tmp_dir/kensi-ai.env" -f platforms/kensi-ai/compose.yaml config >/dev/null` |
| TASK-003 | folder-scoped Compose and shell validation | `shellcheck platforms/agentshq/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/agentshq/generate-env.sh --shared-env "$tmp_dir/platforms/agentshq.shared.env" --output "$tmp_dir/agentshq.env" && docker compose --env-file "$tmp_dir/agentshq.env" -f platforms/agentshq/compose.yaml config >/dev/null` |
| TASK-004 | folder-scoped Compose and shell validation | `shellcheck platforms/open-kudos/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/open-kudos/generate-env.sh --shared-env "$tmp_dir/platforms/open-kudos.shared.env" --output "$tmp_dir/open-kudos.env" && docker compose --env-file "$tmp_dir/open-kudos.env" -f platforms/open-kudos/compose.yaml config >/dev/null` |
| TASK-005 | folder-scoped Compose and shell validation | `shellcheck platforms/insight/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/insight/generate-env.sh --shared-env "$tmp_dir/platforms/insight.shared.env" --output "$tmp_dir/insight.env" && docker compose --env-file "$tmp_dir/insight.env" -f platforms/insight/compose.yaml config >/dev/null` |
| TASK-006 | folder-scoped Compose and shell validation | `shellcheck platforms/togglebox/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/togglebox/generate-env.sh --shared-env "$tmp_dir/platforms/togglebox.shared.env" --output "$tmp_dir/togglebox.env" && docker compose --env-file "$tmp_dir/togglebox.env" -f platforms/togglebox/compose.yaml config >/dev/null` |
| TASK-007 | folder-scoped Compose and shell validation | `shellcheck platforms/openpay/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/openpay/generate-env.sh --shared-env "$tmp_dir/platforms/openpay.shared.env" --output "$tmp_dir/openpay.env" && docker compose --env-file "$tmp_dir/openpay.env" -f platforms/openpay/compose.yaml config >/dev/null` |
| TASK-008 | folder-scoped Compose and shell validation | `shellcheck platforms/ploon/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/ploon/generate-env.sh --shared-env "$tmp_dir/platforms/ploon.shared.env" --output "$tmp_dir/ploon.env" && docker compose --env-file "$tmp_dir/ploon.env" -f platforms/ploon/compose.yaml config >/dev/null` |
| TASK-009 | folder-scoped Compose and shell validation | `shellcheck platforms/open-growth-group/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/open-growth-group/generate-env.sh --shared-env "$tmp_dir/platforms/open-growth-group.shared.env" --output "$tmp_dir/open-growth-group.env" && docker compose --env-file "$tmp_dir/open-growth-group.env" -f platforms/open-growth-group/compose.yaml config >/dev/null` |
| TASK-010 | folder-scoped Compose and shell validation | `shellcheck platforms/lokei/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/lokei/generate-env.sh --shared-env "$tmp_dir/platforms/lokei.shared.env" --output "$tmp_dir/lokei.env" && docker compose --env-file "$tmp_dir/lokei.env" -f platforms/lokei/compose.yaml config >/dev/null` |
| TASK-011 | folder-scoped Compose and shell validation | `shellcheck platforms/albert/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/albert/generate-env.sh --shared-env "$tmp_dir/platforms/albert.shared.env" --output "$tmp_dir/albert.env" && docker compose --env-file "$tmp_dir/albert.env" -f platforms/albert/compose.yaml config >/dev/null` |
| TASK-012 | folder-scoped Compose and shell validation | `shellcheck platforms/record-cloud/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/record-cloud/generate-env.sh --shared-env "$tmp_dir/platforms/record-cloud.shared.env" --output "$tmp_dir/record-cloud.env" && docker compose --env-file "$tmp_dir/record-cloud.env" -f platforms/record-cloud/compose.yaml config >/dev/null` |
| TASK-013 | folder-scoped Compose and shell validation | `shellcheck platforms/plane/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/plane/generate-env.sh --shared-env "$tmp_dir/platforms/plane.shared.env" --output "$tmp_dir/plane.env" && docker compose --env-file "$tmp_dir/plane.env" -f platforms/plane/compose.yaml config >/dev/null` |
| TASK-014 | folder-scoped Compose and shell validation | `shellcheck platforms/postiz/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/postiz/generate-env.sh --shared-env "$tmp_dir/platforms/postiz.shared.env" --output "$tmp_dir/postiz.env" && docker compose --env-file "$tmp_dir/postiz.env" -f platforms/postiz/compose.yaml config >/dev/null` |
| TASK-015 | folder-scoped Compose and shell validation | `shellcheck platforms/nudgra-oss/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/nudgra-oss/generate-env.sh --shared-env "$tmp_dir/platforms/nudgra-oss.shared.env" --output "$tmp_dir/nudgra-oss.env" && docker compose --env-file "$tmp_dir/nudgra-oss.env" -f platforms/nudgra-oss/compose.yaml config >/dev/null` |
| TASK-016 | folder-scoped Compose and shell validation | `shellcheck platforms/n8n/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/n8n/generate-env.sh --shared-env "$tmp_dir/platforms/n8n.shared.env" --output "$tmp_dir/n8n.env" && docker compose --env-file "$tmp_dir/n8n.env" -f platforms/n8n/compose.yaml config >/dev/null` |
| TASK-017 | folder-scoped Compose and shell validation | `shellcheck platforms/twenty/generate-env.sh && tmp_dir=$(mktemp -d) && infrastructure/generate-env.sh --output-dir "$tmp_dir" && platforms/twenty/generate-env.sh --shared-env "$tmp_dir/platforms/twenty.shared.env" --output "$tmp_dir/twenty.env" && docker compose --env-file "$tmp_dir/twenty.env" -f platforms/twenty/compose.yaml config >/dev/null` |

## Execution Summary

- Tasks: 16
- Parallel layers: 1
- Critical path (1 tasks): TASK-002

## Task Dependencies

- TASK-002: None; external: TASK-001
- TASK-003: None; external: TASK-001
- TASK-004: None; external: TASK-001
- TASK-005: None; external: TASK-001
- TASK-006: None; external: TASK-001
- TASK-007: None; external: TASK-001
- TASK-008: None; external: TASK-001
- TASK-009: None; external: TASK-001
- TASK-010: None; external: TASK-001
- TASK-011: None; external: TASK-001
- TASK-012: None; external: TASK-001
- TASK-013: None; external: TASK-001
- TASK-014: None; external: TASK-001
- TASK-015: None; external: TASK-001
- TASK-016: None; external: TASK-001
- TASK-017: None; external: TASK-001
