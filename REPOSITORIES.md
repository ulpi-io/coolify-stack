# Deployment Repositories

This is the authoritative repository scope for the Coolify deployment system.

The repository-grounded service inventory, application dependency matrix, shared/dedicated boundaries, and database-engine preservation policy are defined in `SHARED_INFRASTRUCTURE.md`. Coolify is the external deployment platform; it is not part of the OGG infrastructure stack.

Ownership for repositories 1-15 below: **personal / first-party**.

Environment scope for every deployment unit: **production only**.

## Deployment Units and Domains

| Deployment unit | Repositories/components | Production domain | Source |
| --- | --- | --- | --- |
| Kensi AI | `kensi-ai-api`, `kensi-ai-web` | `https://www.kensi.ai` | Supplied by Ciprian |
| AgentsHQ | `agentshq-api`, `agentshq-web` | `https://www.agentshq.sh/` | Supplied by Ciprian |
| OpenKudos | `open-kudos-api`, `open-kudos-web` | `https://www.teamtoast.ai/` | Supplied by Ciprian |
| Insight | `insight` | `https://www.clavinci.com`, `https://api.clavinci.com` | Supplied by Ciprian |
| Togglebox | `togglebox` | `https://www.togglebox.dev` | Supplied by Ciprian |
| OpenPay | `OpenPayApi`, `OpenPayWeb` | `https://www.openpay.fyi/` | Supplied by Ciprian |
| Ploon | `ploon-web` | `https://www.ploon.ai` | Supplied by Ciprian |
| Open Growth Group website | `open-growth-group-website` | `https://www.opengrowthgroup.co` | Supplied by Ciprian |
| Lokei | `lokei` | `https://www.lokei.dev` | Supplied by Ciprian |
| Albert | `albert` | `https://www.albert.con.fyi`, `https://api.albert.con.fyi` | Supplied by Ciprian |
| Record Cloud | `record-cloud` | `https://www.record.con.fyi` | Supplied by Ciprian |
| Plane | `makeplane/plane` | `https://www.pm.con.fyi` | Coolify route |
| Postiz | `ulpi-io/postiz-docker-compose` | `https://www.post.con.fyi` | Coolify route |
| Nudgra OSS | `MaikoCode/nudgra-oss` | `https://www.ig.con.fyi` | Coolify route |
| n8n | Coolify recipe using `n8nio/n8n:2.10.4` | `https://www.workflow.con.fyi` | Coolify route |
| Twenty | Coolify Marketplace recipe using `twentycrm/twenty:v1.15` | `https://www.crm.con.fyi` | Coolify route |

Domains not listed in this table are still to be collected or verified from the live Coolify deployment.

1. https://github.com/ulpi-io/lokei
2. https://github.com/ulpi-io/albert
3. https://github.com/ulpi-io/record-cloud
4. https://github.com/ulpi-io/insight
5. https://github.com/ulpi-io/kensi-ai-api
    - Deployment unit: Kensi AI
    - Component: API
6. https://github.com/ulpi-io/kensi-ai-web
    - Deployment unit: Kensi AI
    - Component: Web
    - Domain mapping: collect once for the combined Kensi AI deployment
7. https://github.com/ulpi-io/agentshq-web
    - Deployment unit: AgentsHQ
    - Component: Web
8. https://github.com/ulpi-io/agentshq-api
    - Deployment unit: AgentsHQ
    - Component: API
    - Domain mapping: collect once for the combined AgentsHQ deployment
9. https://github.com/ulpi-io/togglebox
10. https://github.com/ulpi-io/ploon-web
11. https://github.com/CiprianSpiridon/open-growth-group-website
12. https://github.com/CiprianSpiridon/OpenPayApi
    - Deployment unit: OpenPay
    - Component: API
13. https://github.com/CiprianSpiridon/OpenPayWeb
    - Deployment unit: OpenPay
    - Component: Web
    - Domain mapping: collect once for the combined OpenPay deployment
14. https://github.com/ulpi-io/open-kudos-api
    - Deployment unit: OpenKudos
    - Component: API
15. https://github.com/ulpi-io/open-kudos-web
    - Deployment unit: OpenKudos
    - Component: Web
    - Domain mapping: collect once for the combined OpenKudos deployment
16. https://github.com/makeplane/plane
    - Ownership: third-party
    - Existing deployment: Coolify recipe already exists
    - Requested change: use the shared PostgreSQL database infrastructure when repository research proves compatibility
17. https://github.com/ulpi-io/postiz-docker-compose
    - Application: Postiz
    - Ownership: personal / first-party fork
    - Deployment source: this fork, which contains issue fixes
    - Upstream: https://github.com/gitroomhq/postiz-docker-compose
18. https://github.com/MaikoCode/nudgra-oss
    - Application: Nudgra OSS
    - Ownership: third-party
19. n8n
    - Ownership: third-party
    - Deployment class: image / Coolify recipe; no application-source repository required
    - Current image: `n8nio/n8n:2.10.4`
    - Existing deployment: running on the production Coolify server
    - Current recipe: `N8N_CURRENT_RECIPE.md`
    - Research source: live deployment metadata plus official image documentation
20. Twenty
    - Ownership: third-party
    - Deployment class: image / Coolify Marketplace recipe; no application-source repository required
    - Current image: `twentycrm/twenty:v1.15`
    - Existing deployment: running on the production Coolify server
    - Current recipe: `TWENTY_CURRENT_RECIPE.md`
    - Research source: live deployment metadata plus official image documentation
