# DigitalOcean Server Agent Runbook

Use this document when an agent needs to inspect or operate Ciprian's DigitalOcean VPS. Treat the server as production infrastructure.

## Connection

- Host: `68.183.135.86`
- SSH user: `root`
- Private key on Ciprian's Mac: `~/.ssh/id_ed25519_digitalocean`
- Public key: `~/.ssh/id_ed25519_digitalocean.pub`

Interactive connection:

```bash
ssh -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519_digitalocean \
  root@68.183.135.86
```

For bounded, non-interactive agent checks:

```bash
ssh -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519_digitalocean \
  root@68.183.135.86 '<read-only command>'
```

Use the private key file, not the `.pub` file. Never print, copy, upload, commit, or request the private key or its passphrase. If the key is not unlocked, ask Ciprian to unlock it locally rather than asking for the passphrase.

## Platform

The VPS is Ubuntu and runs Coolify-managed Docker workloads.

- Coolify: `https://deploy.con.fyi`
- Public ingress: Coolify's Traefik proxy on ports 80 and 443
- Public applications should normally be reached through HTTPS domains, not exposed host ports.
- Coolify-generated Compose files and containers are replaceable deployment artifacts. Make persistent changes through Coolify configuration or the application's source repository.

Known application domains include:

- Twenty CRM: `https://crm.con.fyi`
- Plane: `https://pm.con.fyi`
- Postiz: `https://post.con.fyi`
- Authentik: `https://login.con.fyi`
- n8n: `https://workflow.con.fyi`
- Nudgra: `https://ig.con.fyi`

The stack recipe reserves `https://buzz.con.fyi` for Buzz (desktop/CLI clients
use `wss://buzz.con.fyi`), but its DNS record must be created before deployment.

The SocialReply recipe reserves `https://app.socialreply.com`,
`https://api.socialreply.com`, and `wss://ws.socialreply.com`. Resolve current
DNS and live Coolify state before deployment; the recipe itself does not create
or change those records.

Treat this list as orientation only. Resolve the current Coolify resource, container names, domains, and health at runtime; names and deployment suffixes change after redeployment.

## Required Operating Discipline

1. Start read-only. Identify the exact resource and failure before changing anything.
2. Keep actions scoped to the application named by the user.
3. Prefer Coolify Save + Redeploy for environment or routing changes. A container restart does not apply changed environment variables.
4. Preserve all database and application volumes unless Ciprian explicitly authorizes their deletion after being told the data-loss impact.
5. Never expose or paste complete container environments, Compose secrets, database passwords, OAuth credentials, API keys, or private keys.
6. Do not edit generated files under `/data/coolify` as a durable fix; Coolify can overwrite them on the next deployment.
7. Do not restart Coolify, Traefik, Docker, or unrelated application stacks to fix one service without explicit authorization and evidence that it is necessary.
8. Do not change DNS, firewalls, SSH configuration, operating-system packages, or DigitalOcean control-plane resources unless the request explicitly includes that scope.

Never run broad destructive commands such as:

```text
docker system prune --all --volumes
docker volume prune
docker compose down --volumes
rm -rf /data/coolify
```

## Read-Only Diagnostic Workflow

List current containers and health:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
```

Inspect a selected container's state and configured healthcheck:

```bash
docker inspect --format \
  'state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} exit={{.State.ExitCode}} error={{.State.Error}}' \
  '<container>'

docker inspect --format '{{json .Config.Healthcheck}}' '<container>'
```

Read a bounded log tail:

```bash
docker logs --timestamps --tail 200 '<container>' 2>&1
```

Inspect routing labels without dumping the environment:

```bash
docker inspect --format '{{json .Config.Labels}}' '<container>'
```

When checking environment configuration, request only known non-secret names. Never dump all variables:

```bash
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' '<container>' \
  | grep -E '^(SITE_URL|SERVER_URL|FRONT_BASE_URL|TRUSTED_ORIGINS)='
```

Verify a public endpoint from the VPS:

```bash
curl -sS -I --max-time 20 'https://app.example.com/'
```

Test the local Traefik route while bypassing public DNS:

```bash
curl -ksS \
  --resolve 'app.example.com:443:127.0.0.1' \
  'https://app.example.com/health'
```

Use `-k` only for this loopback routing diagnostic. Do not use it to declare public TLS healthy. A normal public `curl` without `-k` must also succeed.

## DNS Diagnostics

Compare the system resolver with independent public resolvers:

```bash
dig +short app.example.com A
dig @1.1.1.1 +short app.example.com A
dig @8.8.8.8 +short app.example.com A
```

The Mac has previously used FortiGuard resolvers (`96.45.45.45` and `96.45.46.46`), which can disagree temporarily after a new DNS record is added. If public resolvers return `68.183.135.86` but the system resolver returns `NXDOMAIN`, the application and Coolify deployment are not the cause. Diagnose the active DNS/VPN/security filter or wait for its negative cache to expire.

## Safe Change and Verification Pattern

For an authorized application change:

1. Capture the current container state, relevant bounded logs, and routing labels.
2. Make the smallest durable change through Coolify or the source repository.
3. Redeploy only the affected resource.
4. Confirm every expected service is running and healthy.
5. Test the internal health route and the public HTTPS URL.
6. Inspect fresh browser network/console behavior when the issue is frontend-facing.
7. Report exactly what changed, what was verified, and any remaining risk.

To deploy the complete already-configured stack in dependency order through the
Coolify API, use:

```bash
scripts/deploy-resources.sh --apply \
  --ssh-key ~/.ssh/id_ed25519_digitalocean
```

The script deploys shared infrastructure first and then each platform. It opens
Coolify's localhost-only API only for the duration of the run and revokes its
temporary token on exit. It does not create, delete, or reconfigure resources.

Redeploy one resource without touching any other application:

```bash
scripts/deploy-resources.sh --apply \
  --only kensi-ai \
  --ssh-key ~/.ssh/id_ed25519_digitalocean
```

If an operation would delete data, rotate secrets, alter network access, or affect multiple applications, stop and obtain explicit authorization first.
